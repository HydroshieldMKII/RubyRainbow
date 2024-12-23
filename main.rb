require_relative 'rtgenerator'

params = {
    hash_algorithm: 'SHA256',
    salt: '',
    min_length: 1,
    max_length: 3,
    include_uppercase: true,
    include_digits: true,
    include_special: true,
    number_of_threads: 6
}

rt_generator = RTGenerator.new(params)

# Uncomment the following lines to customize the character sets
# rt_generator.base_charset = ('x'..'z').to_a
# rt_generator.uppercase_charset = ('M'..'P').to_a
# rt_generator.digits_charset = ('4'..'7').to_a
# rt_generator.special_charset = ['@', '#', '$']

# Benchmark the generation of hashes with current parameters
rt_generator.benchmark(benchmark_time: 10)

# Compute all the hashes and output the results to a file (Text, CSV or JSON)
rt_generator.compute_table(output_path: 'table.txt', overwrite_file: true)

# Compute all the hashes until a specific hash is found
hash, value = rt_generator.compute_table(hash_to_find: 'c2b4122023906a07d7bf7a99304b58cbc2a3f7df3e8db9b7fa1e2886c6c48705')
puts "Hash found: #{hash}:#{value}"

# Compute all the hashes and output the results (Text, CSV or JSON) until a specific hash is found
rt_generator.compute_table(output_path: 'table.txt', overwrite_file: true, hash_to_find: '0bb06b11a595c5ae522f41caccab078890a882a168eca4c69ece3df1c38afb3e')


