require 'thread'
require 'digest'
require 'json'
require 'csv'

class RTGenerator
    def initialize(params)
        # Validate required parameters
        required_params = %i[hash_algorithm salt min_length max_length number_of_threads include_uppercase include_digits include_special]
        missing_params = required_params - params.keys
        raise "Missing required parameters: #{missing_params}" unless missing_params.empty?

        # Validate hash algorithm
        allowed_algorithms = %w[MD5 SHA1 SHA256 SHA384 SHA512 RMD160]
        raise "Invalid hash algorithm" unless allowed_algorithms.include?(params[:hash_algorithm])

        # Validate parameters
        raise "Invalid length" unless params[:min_length].is_a?(Integer) && params[:max_length].is_a?(Integer) && params[:min_length] > 0 && params[:max_length] > 0 && params[:min_length] <= params[:max_length]
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
        raise "Already computing" if @is_computing
        raise "Invalid benchmark time" unless benchmark_time.is_a?(Integer) && benchmark_time > 0
        #Warnings
        puts "Warning: Benchmark time is too short. Minimum recommended time is 10 seconds." if benchmark_time < 10

        # Generate combinations lazily
        combinations = generate_combinations()
        puts "Benchmarking (#{benchmark_time} seconds). Ctrl+C to cancel..."
        puts "Warning: Combination size is over 1 000 000. This may take a while." if combinations.size > 1000000

        hashes_generated = 0
        threads = []
        start_time = Time.now
        mutex = Mutex.new

        # Add warning if benchmark time is too short or 

        # Handle Ctrl+C to display results early
        trap("INT") do
            puts "\nBenchmark interrupted. Aborting..."
            threads.each(&:exit)
            elapsed_time = Time.now - start_time
            display_benchmark_results(elapsed_time, hashes_generated, combinations.size)
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

        # Benchmark done before benchmark_time
        if timer_thread.alive?
            puts "Benchmark done early."
            timer_thread.exit
        end

        elapsed_time = Time.now - start_time
        display_benchmark_results(elapsed_time, hashes_generated, combinations.size)
    end

    # Compute a table of hashes and output the results to a file (Text, CSV or JSON)
    def compute_table(output_path: nil, overwrite_file: false, hash_to_find: nil)
        raise "Already computing" if @is_computing
        raise "Output path cannot be empty" if output_path && output_path.empty?
        raise "Output file already exists and not overwriting. Use overwrite_file: true" if output_path && File.exist?(output_path) && !overwrite_file

        if output_path
            @table = {}
            supported_extensions = %w[txt csv json]
            output_type = output_path.split('.').last
            raise "Unsupported output extension: #{output_type}" unless supported_extensions.include?(output_type)
        end

        @is_computing = true

        start_time = Time.now
        combinations = generate_combinations()

        threads = []
        mutex = Mutex.new
        slice_size = (combinations.size / @params[:number_of_threads].to_f).ceil
        workloads = combinations.each_slice(slice_size).to_a

        puts "== Starting computation with current parameters =="
        puts "Hash algorithm: #{@params[:hash_algorithm]}"
        puts "Salt: #{@params[:salt]}"
        puts "Minimum Length: #{@params[:min_length]}"
        puts "Maximum Length: #{@params[:max_length]}"
        puts "Hashes to find: #{hash_to_find}"
        puts "Include uppercase: #{@params[:include_uppercase]}"
        puts "Include digits: #{@params[:include_digits]}"
        puts "Include special: #{@params[:include_special]}"
        puts "Output path: #{output_path}"
        puts "Overwrite file: #{overwrite_file}"
        puts "Number of threads: #{@params[:number_of_threads]}"
        puts "Computing... Ctrl+C to cancel"

        workloads.each do |workload|
            threads << Thread.new do
                workload.each do |plain_text|
                    hash = hash(@params[:salt] + plain_text)

                    if hash_to_find && hash == hash_to_find
                        puts "Found hash: #{hash} => #{plain_text}"
                        threads.each(&:exit)
                    end
                
                    if output_path
                        mutex.synchronize do
                            @table[hash] = plain_text
                        end
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
        puts "Computation done! Time elapsed: #{format_time(Time.now - start_time)}"

        if output_path
            puts "Outputting table to file..."
            output_table(output_path)
        end

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

    def generate_combinations()
        puts "Generating combinations..."
        charset = ('a'..'z').to_a
        charset += ('A'..'Z').to_a if @params[:include_uppercase]
        charset += ('0'..'9').to_a if @params[:include_digits]
        charset += ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')'] if @params[:include_special]

        combinations = []
        mutex = Mutex.new
        threads = []

        slice_size = ((@params[:max_length] - @params[:min_length] + 1) / @params[:number_of_threads].to_f).ceil
        (@params[:min_length]..@params[:max_length]).each_slice(slice_size) do |lengths|
            threads << Thread.new do
                lengths.each do |length|
                    charset.repeated_permutation(length).lazy.each do |combination|
                        mutex.synchronize do
                            combinations << combination.join
                        end
                    end
                end
            end
        end

        threads.each(&:join)
        combinations
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

    def display_benchmark_results(elapsed_time, hashes_generated, combinations_size)
        hashes_per_second = (hashes_generated / elapsed_time).round(2)
        approximate_time = combinations_size / hashes_per_second
        approximate_time_str = format_time(approximate_time)
    
        puts "=== Benchmark Details ==="
        puts "Hash algorithm: #{@params[:hash_algorithm]}"
        puts "Salt: #{@params[:salt]}"
        puts "Length range: #{@params[:min_length]} to #{@params[:max_length]}"
        puts "Benchmark time: #{elapsed_time.round(2)} seconds"
        puts "Hashes generated: #{hashes_generated}"
        puts "Hashes generated per second: #{hashes_per_second} H/s"
        puts "Hashes per thread: #{(hashes_per_second / @params[:number_of_threads]).round(2)} H/s per thread"
        puts "Total combinations: #{combinations_size}"
        puts "Estimated time to compute all combinations: #{approximate_time_str}"
        puts "=========================="
    end
    
    # Format time into hours, minutes, and seconds from seconds
    def format_time(seconds)
        hrs = (seconds / 3600).floor
        mins = ((seconds % 3600) / 60).floor
        secs = (seconds % 60).round
        "#{hrs}h #{mins}m #{secs}s"
    end
end
