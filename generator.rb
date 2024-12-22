require 'digest'

class RTGenerator
    def initialize(params)
        required_params = %i[hash_algorithm salt length number_of_threads]
        missing_params = required_params - params.keys
        raise "Missing required parameters: #{missing_params}" unless missing_params.empty?

        @params = params
        @table = {}
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
            puts "\nBenchmark interrupted."
            threads.each(&:exit)
            elapsed_time = Time.now - start_time
            display_results(elapsed_time, hashes_generated)
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
        display_results(elapsed_time, hashes_generated)
    end

    # Compute a table of hashes
    def compute_table(value: nil, )
        # Based on parameters, generate a table of hashes
    end

    private

    def hash(plain_text)
        case @params[:hash_algorithm]
            when 'MD5'
                Digest::MD5.hexdigest(@params[:salt] + plain_text)
            when 'SHA1'
                Digest::SHA1.hexdigest(@params[:salt] + plain_text)
            when 'SHA256'
                Digest::SHA256.hexdigest(@params[:salt] + plain_text)
            when 'SHA512'
                Digest::SHA512.hexdigest(@params[:salt] + plain_text)
        else
            raise "Unsupported hash algorithm: #{@params[:hash_algorithm]}"
        end
    end

    def generate_combinations(length)
        puts "Generating combinations..."
        charset = ('a'..'z').to_a
        charset += ('A'..'Z').to_a if @params[:include_uppercase]
        charset += ('0'..'9').to_a if @params[:include_digits]

        charset.repeated_permutation(length).lazy.map(&:join)
    end

    def display_results(elapsed_time, hashes_generated)
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
