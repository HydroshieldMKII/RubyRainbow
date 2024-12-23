require 'thread'
require 'digest'
require 'json'
require 'csv'
require 'parallel'
require 'ruby-progressbar'

class RTGenerator
    attr_writer :charset, :uppercase_charset, :digits_charset, :special_charset
    def initialize(params)
        required_params = %i[hash_algorithm salt min_length max_length number_of_threads include_uppercase include_digits include_special]
        missing_params = required_params - params.keys
        raise "Missing required parameters: #{missing_params}" unless missing_params.empty?

        allowed_algorithms = %w[MD5 SHA1 SHA256 SHA384 SHA512 RMD160]
        raise "Invalid hash algorithm" unless allowed_algorithms.include?(params[:hash_algorithm])

        raise "Invalid length" unless params[:min_length].is_a?(Integer) && params[:max_length].is_a?(Integer) &&
                                      params[:min_length] > 0 && params[:max_length] > 0 &&
                                      params[:min_length] <= params[:max_length]
        raise "Invalid number of threads" unless params[:number_of_threads].is_a?(Integer) && params[:number_of_threads] > 0

        %i[include_uppercase include_digits include_special].each do |key|
            raise "Invalid #{key}" unless [true, false].include?(params[key])
        end

        raise "Invalid salt" unless params[:salt].is_a?(String)

        @params = params
        @table = {}
        @base_charset = ('a'..'z').to_a
        @uppercase_charset = ('A'..'Z').to_a
        @digits_charset = ('0'..'9').to_a
        @special_charset = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')']
    end

    def benchmark(benchmark_time: 10)
        raise "Invalid benchmark time" unless benchmark_time.is_a?(Integer) && benchmark_time > 0
    
        combinations = generate_combinations
        total_combinations = combinations.size
        start_time = Time.now
        hashes_generated = 0
    
        # Progress bar
        progress_bar = ProgressBar.create(
            title: "Benchmarking",
            total: total_combinations,
            format: "%t |%B| %p%% %e",
            throttle_rate: 0.1
        )
    
        begin
            Parallel.each(combinations, in_threads: @params[:number_of_threads]) do |plain_text|
                # Check if the time limit has been reached
                raise Parallel::Break if Time.now - start_time >= benchmark_time
    
                hash(plain_text) # Perform hashing
                hashes_generated += 1
    
                # Update the progress bar
                progress_bar.increment
            end
        rescue Parallel::Break
            puts "\nBenchmark interrupted: Time limit reached"
        ensure
            elapsed_time = Time.now - start_time
            progress_bar.finish
            display_benchmark_results(elapsed_time, hashes_generated, total_combinations)
        end
    end

    def compute_table(output_path: nil, overwrite_file: false, hash_to_find: nil)
        raise "Output file already exists. Use overwrite_file: true" if output_path && File.exist?(output_path) && !overwrite_file

        combinations = generate_combinations
        total_combinations = combinations.size

        # Progress bar
        progress_bar = ProgressBar.create(
            title: "Computing Table",
            total: total_combinations,
            format: "%t |%B| %p%% %e",
            throttle_rate: 0.1
        )

        Parallel.each(combinations, in_threads: @params[:number_of_threads]) do |plain_text|
            hashed_value = hash(plain_text)
            if hash_to_find && hashed_value == hash_to_find
                puts "Found hash: #{hashed_value} => #{plain_text}"
                exit
            end
            @table[hashed_value] = plain_text if output_path

            # Update the progress bar
            progress_bar.increment
        end

        progress_bar.finish
        output_table(output_path) if output_path
        puts "Computation complete!"
    end

    private

    def generate_combinations
        charset = @base_charset
        charset += @uppercase_charset if @params[:include_uppercase]
        charset += @digits_charset if @params[:include_digits]
        charset += @special_charset if @params[:include_special]
    
        Enumerator.new do |yielder|
            (@params[:min_length]..@params[:max_length]).each do |length|
                charset.repeated_permutation(length).each do |combination|
                    yielder << combination.join
                end
            end
        end
    end
    
    

    def hash(pre_digest)
        salted = "#{@params[:salt]}#{pre_digest}"
        case @params[:hash_algorithm]
        when 'MD5' then Digest::MD5.hexdigest(salted)
        when 'SHA1' then Digest::SHA1.hexdigest(salted)
        when 'SHA256' then Digest::SHA256.hexdigest(salted)
        when 'SHA384' then Digest::SHA384.hexdigest(salted)
        when 'SHA512' then Digest::SHA512.hexdigest(salted)
        when 'RMD160' then Digest::RMD160.hexdigest(salted)
        else raise "Unsupported hash algorithm: #{@params[:hash_algorithm]}"
        end
    end

    def output_table(output_path)
        File.open(output_path, 'w') do |file|
            case output_path.split('.').last
            when 'txt'
                @table.each { |hash, plain_text| file.puts "#{hash}:#{plain_text}" }
            when 'csv'
                CSV.open(output_path, 'wb') { |csv| @table.each { |hash, plain_text| csv << [hash, plain_text] } }
            when 'json'
                file.puts JSON.pretty_generate(@table)
            else
                raise "Unsupported output type"
            end
        end
    end

    def display_benchmark_results(elapsed_time, hashes_generated, combinations_size)
        hashes_per_second = (hashes_generated / elapsed_time).round(2)
        puts "Benchmark completed:"
        puts "- Elapsed Time: #{elapsed_time.round(2)} seconds"
        puts "- Hashes Generated: #{hashes_generated}"
        puts "- Hashes per Second: #{hashes_per_second} H/s"
        puts "- Total Combinations: #{combinations_size}"
    end
end
