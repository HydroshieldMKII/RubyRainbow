require 'thread'
require 'timeout'
require 'digest'
require 'json'
require 'csv'
require 'parallel'
require 'ruby-progressbar'

class RTGenerator
    attr_writer :charset, :uppercase_charset, :digits_charset, :special_charset
    def initialize(params)
        # Validate parameters
        required_params = %i[hash_algorithm salt min_length max_length number_of_threads include_uppercase include_digits include_special]
        missing_params = required_params - params.keys
        raise "Missing required parameters: #{missing_params}" unless missing_params.empty?

        # Validate algorithm
        allowed_algorithms = %w[MD5 SHA1 SHA256 SHA384 SHA512 RMD160]
        raise "Invalid hash algorithm" unless allowed_algorithms.include?(params[:hash_algorithm])

        # Validate length
        raise "Invalid length" unless params[:min_length].is_a?(Integer) && params[:max_length].is_a?(Integer) &&
                                      params[:min_length] > 0 && params[:max_length] > 0 &&
                                      params[:min_length] <= params[:max_length]
        raise "Invalid number of threads" unless params[:number_of_threads].is_a?(Integer) && params[:number_of_threads] > 0

        # Validate boolean parameters
        %i[include_uppercase include_digits include_special].each do |key|
            raise "Invalid #{key}" unless [true, false].include?(params[key])
        end

        # Validate salt
        raise "Invalid salt" unless params[:salt].is_a?(String)

        @table = {}
        @params = params

        # Default charsets, can be overridden
        @base_charset = ('a'..'z').to_a
        @uppercase_charset = ('A'..'Z').to_a
        @digits_charset = ('0'..'9').to_a
        @special_charset = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')']
    end

    def benchmark(benchmark_time: 10)
        raise "Invalid benchmark time" unless benchmark_time.is_a?(Integer) && benchmark_time > 0
        charset = @base_charset
        charset += @uppercase_charset if @params[:include_uppercase]
        charset += @digits_charset if @params[:include_digits]
        charset += @special_charset if @params[:include_special]

        total_combinations = charset.repeated_permutation(@params[:max_length]).size
        hashes_generated = 0
        start_time = Time.now

        # Progress bar
        progress_bar = ProgressBar.create(
            title: "Benchmarking",
            total: benchmark_time,
            format: "%t |%B| %p%% %e",
            throttle_rate: 0.5
        )

        Thread.new do
            loop do
                sleep 1
                progress_bar.increment
                break if Time.now - start_time >= benchmark_time
            end
            progress_bar.finish
        end

        begin   
            Timeout.timeout(benchmark_time) do
                charset.repeated_permutation(@params[:max_length]).each do |combination|
                    hash(combination.join)
                    hashes_generated += 1
                end
            end
        rescue Timeout::Error
        end

        progress_bar.finish
        elapsed_time = Time.now - start_time
        display_benchmark_results(elapsed_time, hashes_generated, total_combinations)
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
        puts "- Total hashes computed: #{hashes_generated} H"
        puts "- Total hashes computed per Thread: #{(hashes_generated / @params[:number_of_threads].to_f).round(2)} H"
        puts "- Hashes computed per Second: #{hashes_per_second} H/s"
        puts "- Hashes computed per Minute: #{(hashes_per_second * 60).round(2)} H/m"
        puts "- Total Generated Combinations: #{combinations_size} H"
    end
end
