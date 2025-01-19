require_relative 'rrainbow.rb'

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

rr = RubyRainbow.new(params)

# Uncomment the following lines to customize the character sets
# rr.base_charset = ('x'..'z').to_a
# rr.uppercase_charset = ('M'..'P').to_a
# rr.digits_charset = ('4'..'7').to_a
# rr.special_charset = ['@', '#', '$']

# Benchmark the generation of hashes with current parameters
rr.benchmark(benchmark_time: 10)

# Compute all the hashes and output the results to a file (Text, CSV or JSON)
rr.compute_table(output_path: 'table.txt', overwrite_file: true)

# Compute all the hashes until a specific hash is found
hash, value = rr.compute_table(hash_to_find: 'c2b4122023906a07d7bf7a99304b58cbc2a3f7df3e8db9b7fa1e2886c6c48705')
puts "Hash found: #{hash}:#{value}"


