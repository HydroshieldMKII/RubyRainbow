require 'digest'

class RTGenerator
    def initialize(params)
        required_params = %i[hash_algorithm salt length number_of_threads include_uppercase include_digits include_special]
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
        supported_extensions = %w[txt csv json]
        output_type = output_path.split('.').last
        raise "Unsupported output extension: #{output_type}" unless supported_extensions.include?(output_type)

        start_time = Time.now
        combinations = generate_combinations(@params[:length])

        mutex = Mutex.new
        threads = []
        slice_size = (combinations.size / @params[:number_of_threads].to_f).ceil

        puts "Computing table with #{@params[:number_of_threads]} threads..."
        @params[:number_of_threads].times do
            threads << Thread.new do
                combinations.each do |plain_text|
                    hash = hash(plain_text)
                    mutex.synchronize do
                        @table[hash] = plain_text
                    end
                end
            end
        end

        threads.each(&:join)

        output_table(output_path, output_type)
        puts "Table saved to #{output_path}. Time elapsed: #{(Time.now - start_time).round(2)} seconds"
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
        charset += ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')'] if @params[:include_special]

        charset.repeated_permutation(length).lazy.map(&:join)
    end

    def output_table(output_path, type)
        if type == 'text'
            File.open(output_path, 'w') do |file|
                @table.each do |hash, plain_text|
                    file.puts "#{hash}:#{plain_text}"
                end
            end
        elsif type == 'csv'
            require 'csv'
            CSV.open(output_path, 'wb') do |csv|
                @table.each do |hash, plain_text|
                    csv << [hash, plain_text]
                end
            end
        elsif type == 'json'
            require 'json'
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
