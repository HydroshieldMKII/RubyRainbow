require 'thread'
require 'timeout'
require 'digest'
require 'json'
require 'csv'
require 'concurrent-ruby'
require 'ruby-progressbar'

class RubyRainbow
    attr_writer :base_charset, :uppercase_charset, :digits_charset, :special_charset

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
        
        # Pre-compute hash class
        @hash_class = case @params[:hash_algorithm]
                      when 'MD5' then Digest::MD5
                      when 'SHA1' then Digest::SHA1
                      when 'SHA256' then Digest::SHA256
                      when 'SHA384' then Digest::SHA384
                      when 'SHA512' then Digest::SHA512
                      when 'RMD160' then Digest::RMD160
                      end
        
        # Pre-allocate salt bytes
        @salt_bytes = @params[:salt].b
        @salt_size = @salt_bytes.bytesize
    end

    def benchmark(benchmark_time: 10)
        raise "Invalid benchmark time" unless benchmark_time.is_a?(Integer) && benchmark_time > 0

        charset = build_charset
        total_combinations = calculate_total_combinations(charset)
        hashes_generated = Concurrent::AtomicFixnum.new(0)
        start_time = Time.now

        # Progress bar
        progress_bar = ProgressBar.create(
            title: "Benchmarking",
            total: benchmark_time,
            format: "\e[0;32m%t |%B| %p%% %e\e[0m",
            throttle_rate: 0.5,
            progress_mark: '█',
            remainder_mark: '░',
            color: :green
        )

        t = Thread.new do
            (0..benchmark_time).each do |i|
                progress_bar.increment unless progress_bar.finished?
                sleep 1
            end
        end

        begin
            Timeout.timeout(benchmark_time) do
                pool = Concurrent::FixedThreadPool.new(@params[:number_of_threads])
                thread_resources = Concurrent::Map.new
                combinations = generate_combinations_fast(charset)
                
                combinations.each do |plain_text|
                    pool.post do
                        thread_id = Thread.current.object_id
                        resources = thread_resources.compute_if_absent(thread_id) do
                            {
                                digest: @hash_class.new,
                                buffer: String.new(capacity: 256)
                            }
                        end
                        
                        hash_fast(plain_text, resources[:digest], resources[:buffer])
                        hashes_generated.increment
                    end
                end
                
                pool.shutdown
                pool.wait_for_termination
            end
        rescue Timeout::Error
            t.kill
        end

        t.join

        progress_bar.finish
        elapsed_time = Time.now - start_time
        display_benchmark_results(elapsed_time, hashes_generated.value, total_combinations)
    end

    def compute_table(output_path: nil, overwrite_file: false, hash_to_find: nil)
        raise "Output file already exists and no overwrite specified. Use 'overwrite_file: true' when calling this function to replace the specified file." if output_path && File.exist?(output_path) && !overwrite_file
        raise "Invalid output path" if output_path && !output_path.is_a?(String)
        raise "Invalid hash to find" if hash_to_find && !hash_to_find.is_a?(String)
        raise "Ambiguity! You can't output the table and search for a hash at the same time." if output_path && hash_to_find

        charset = build_charset
        total_combinations = calculate_total_combinations(charset)
        puts "Total combinations: #{total_combinations}"
        
        processed = Concurrent::AtomicFixnum.new(0)
        last_update = Concurrent::AtomicReference.new(Time.now)
        table_mutex = Mutex.new if output_path

        # Progress bar
        progress_bar = ProgressBar.create(
            title: output_path ? "Computing Table" : "Searching Hash",
            total: total_combinations,
            format: "\e[0;34m%t |%B| %p%% %e\e[0m",
            throttle_rate: 0.5,
            progress_mark: '█',
            remainder_mark: '░',
            color: :blue
        )

        result = Concurrent::AtomicReference.new(nil)
        stop_flag = Concurrent::AtomicBoolean.new(false)
        
        # Create thread pool and thread-local resources
        pool = Concurrent::FixedThreadPool.new(@params[:number_of_threads])
        thread_resources = Concurrent::Map.new
        
        # Queue for batch processing
        work_queue = Queue.new
        batch_size = 1000
        
        # Producer thread
        producer = Thread.new do
            batch = []
            generate_combinations_fast(charset).each do |plain_text|
                batch << plain_text
                if batch.size >= batch_size
                    work_queue << batch
                    batch = []
                end
                break if stop_flag.value
            end
            work_queue << batch unless batch.empty?
            @params[:number_of_threads].times { work_queue << :done }
        end
        
        # Worker futures
        futures = @params[:number_of_threads].times.map do
            Concurrent::Future.execute(executor: pool) do
                thread_id = Thread.current.object_id
                resources = thread_resources.compute_if_absent(thread_id) do
                    {
                        digest: @hash_class.new,
                        buffer: String.new(capacity: 256)
                    }
                end
                
                loop do
                    batch = work_queue.pop
                    break if batch == :done || stop_flag.value
                    
                    batch.each do |plain_text|
                        break if stop_flag.value
                        
                        hashed_value = hash_fast(plain_text, resources[:digest], resources[:buffer])
                        
                        if hash_to_find && hashed_value == hash_to_find
                            result.set([hashed_value, plain_text])
                            stop_flag.value = true
                            break
                        end
                        
                        if output_path
                            table_mutex.synchronize { @table[hashed_value] = plain_text }
                        end
                    end
                    
                    # Update progress
                    new_processed = processed.update { |v| v + batch.size }
                    if new_processed % 5000 == 0
                        current_time = Time.now
                        last_time = last_update.get
                        if current_time - last_time > 0.1
                            progress_bar.progress = new_processed
                            last_update.set(current_time)
                        end
                    end
                end
            end
        end
        
        # Wait for completion
        producer.join
        futures.each(&:wait!)
        pool.shutdown
        pool.wait_for_termination
        
        progress_bar.finish

        if hash_to_find
            return result.get
        elsif output_path
            output_table(output_path)
        end
    end

    private

    def build_charset
        charset = @base_charset.dup
        charset.concat(@uppercase_charset) if @params[:include_uppercase] && !@uppercase_charset.empty?
        charset.concat(@digits_charset) if @params[:include_digits] && !@digits_charset.empty?
        charset.concat(@special_charset) if @params[:include_special] && !@special_charset.empty?
        charset
    end

    def calculate_total_combinations(charset)
        total = 0
        charset_size = charset.size
        (@params[:min_length]..@params[:max_length]).each do |length|
            total += charset_size ** length
        end
        total
    end

    def generate_combinations_fast(charset)
        puts "Generating combinations..."
        puts "This may take a while depending on the parameters."
        
        charset_size = charset.size
        
        Enumerator.new do |yielder|
            (@params[:min_length]..@params[:max_length]).each do |length|
                buffer = Array.new(length, 0)
                string_buffer = String.new(capacity: length)
                
                loop do
                    # Build string from indices
                    string_buffer.clear
                    buffer.each { |idx| string_buffer << charset[idx] }
                    yielder << string_buffer.dup
                    
                    # Increment indices
                    carry = 1
                    (length - 1).downto(0) do |i|
                        buffer[i] += carry
                        if buffer[i] >= charset_size
                            buffer[i] = 0
                        else
                            carry = 0
                            break
                        end
                    end
                    
                    break if carry == 1
                end
            end
        end
    end

    def hash_fast(pre_digest, digest_obj, buffer = nil)
        # Reuse buffer if provided, otherwise allocate new
        if buffer
            buffer.clear
            buffer << @salt_bytes
            buffer << pre_digest
        else
            buffer = @salt_bytes + pre_digest
        end
        
        # Reset and compute hash
        digest_obj.reset
        digest_obj.update(buffer)
        digest_obj.hexdigest
    end

    def output_table(output_path)
        puts "Outputting table to #{output_path}..."
        
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