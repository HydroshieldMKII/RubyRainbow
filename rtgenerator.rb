require 'thread'
require 'digest'
require 'json'
require 'csv'

class RTGenerator
    def initialize(params)
        # Validate required parameters
        required_params = %i[hash_algorithm salt length number_of_threads include_uppercase include_digits include_special]
        missing_params = required_params - params.keys
        raise "Missing required parameters: #{missing_params}" unless missing_params.empty?

        # Validate hash algorithm
        allowed_algorithms = %w[MD5 SHA1 SHA256 SHA384 SHA512 RMD160]
        raise "Invalid hash algorithm" unless allowed_algorithms.include?(params[:hash_algorithm])

        # Validate parameters
        raise "Invalid length" unless params[:length].is_a?(Integer) && params[:length] > 0
        raise "Invalid number of threads" unless params[:number_of_threads].is_a?(Integer) && params[:number_of_threads] > 0
        raise "Invalid include_uppercase" unless [true, false].include?(params[:include_uppercase])
        raise "Invalid include_digits" unless [true, false].include?(params[:include_digits])
        raise "Invalid include_special" unless [true, false].include?(params[:include_special])
        raise "Invalid salt" unless params[:salt].is_a?(String)

        @is_computing = false
        @params = params # Set parameters
        @table = {} # Table to store hashes and plain texts
    end

    # Benchmark the generation of hashes with current parameters
    def benchmark(benchmark_time: 10)
        hashes_generated = 0
        threads = []
        start_time = Time.now
        mutex = Mutex.new

        # Generate combinations lazily
        combinations = generate_combinations(@params[:length])
        puts "Benchmarking (#{benchmark_time} seconds). Ctrl+C to cancel..."

        # Handle Ctrl+C to display results early
        trap("INT") do
            puts "\nBenchmark interrupted. Aborting..."
            threads.each(&:exit)
            elapsed_time = Time.now - start_time
            display_benchmark_results(elapsed_time, hashes_generated)
            exit
        end

        # Divide work among threads
        @params[:number_of_threads].times do
            threads << Thread.new do
                combinations.each do |plain_text|
                    hash(plain_text) # Execute hash function
                    mutex.synchronize do
                        hashes_generated += 1
                    end
                end
            end
        end

        timer_thread = Thread.new do
            sleep benchmark_time
            puts "Stopping benchmark..."
            threads.each(&:exit)
        end

        threads.each(&:join)
        timer_thread.join

        elapsed_time = Time.now - start_time
        display_benchmark_results(elapsed_time, hashes_generated)
    end

    # Compute a table of hashes and output the results to a file (Text, CSV or JSON)
    def compute_table(output_path: 'table.txt')
        raise "Invalid output path" if output_path.empty? || output_path.nil?

        supported_extensions = %w[txt csv json]
        output_type = output_path.split('.').last
        raise "Unsupported output extension: #{output_type}" unless supported_extensions.include?(output_type)

        @table = {}
        @is_computing = true

        start_time = Time.now
        combinations = generate_combinations(@params[:length])

        threads = []
        mutex = Mutex.new
        slice_size = (combinations.size / @params[:number_of_threads].to_f).ceil

        puts "== Starting computation with current parameters =="
        puts "Hash algorithm: #{@params[:hash_algorithm]}"
        puts "Salt: #{@params[:salt]}"
        puts "Length: #{@params[:length]}"
        puts "Number of threads: #{@params[:number_of_threads]}"
        puts "Output path: #{output_path}"
        puts "Computing... Ctrl+C to cancel"

        @params[:number_of_threads].times do
            threads << Thread.new do
                combinations.each do |plain_text|
                    hash = hash(@params[:salt] + plain_text)
                    mutex.synchronize do
                        @table[hash] = plain_text
                    end
                end
            end
        end

        trap("INT") do
            puts "\nComputation interrupted. Aborting..."
            threads.each(&:exit)
            exit
        end

        threads.each(&:join)

        output_table(output_path)
        puts "Compute done! Table saved to #{output_path}. Time elapsed: #{(Time.now - start_time).round(2)} seconds"

        @is_computing = false
    end

    private

    def hash(pre_digest)
        case @params[:hash_algorithm]
            when 'MD5'
                Digest::MD5.hexdigest(pre_digest)
            when 'SHA1'
                Digest::SHA1.hexdigest(pre_digest)
            when 'SHA256'
                Digest::SHA256.hexdigest(pre_digest)
            when 'SHA384'
                Digest::SHA384.hexdigest(pre_digest)
            when 'SHA512'
                Digest::SHA512.hexdigest(pre_digest)
            when 'RMD160'
                Digest::RMD160.hexdigest(pre_digest)
        else
            raise "Unsupported hash algorithm: #{@params[:hash_algorithm]}"
        end
    end

    def generate_combinations(length)
        puts "Generating combinations..."
        charset = ('a'..'z').to_a
        charset += ('A'..'Z').to_a if @params[:include_uppercase]
        charset += ('0'..'9').to_a if @params[:include_digits]
        charset += ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')'] if @params[:include_special]

        charset.repeated_permutation(length).lazy.map(&:join)
    end

    def output_table(output_path)
        extension = output_path.split('.').last
        
        if extension == 'txt'
            File.open(output_path, 'w') do |file|
                @table.each do |hash, plain_text|
                    file.puts "#{hash}:#{plain_text}"
                end
            end
        elsif extension == 'csv'
            CSV.open(output_path, 'wb') do |csv|
                @table.each do |hash, plain_text|
                    csv << [hash, plain_text]
                end
            end
        elsif extension == 'json'
            File.open(output_path, 'w') do |file|
                file.puts JSON.pretty_generate(@table)
            end
        else
            raise "Unsupported output type: #{type}"
        end
    end

    def display_benchmark_results(elapsed_time, hashes_generated)
        puts "=== Benchmark Details ==="
        puts "Hash algorithm: #{@params[:hash_algorithm]}"
        puts "Salt: #{@params[:salt]}"
        puts "Length: #{@params[:length]}"
        puts "Benchmark time: #{elapsed_time.round(2)} seconds"
        puts "Hashes generated: #{hashes_generated}"
        puts "Hashes per second: #{(hashes_generated / elapsed_time).round(2)}"
        puts "Hashes per thread: #{(hashes_generated / elapsed_time / @params[:number_of_threads]).round(2)}"
        puts "=========================="
    end
end
