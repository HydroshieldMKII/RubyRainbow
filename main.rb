require_relative 'rtgenerator'

params = {
    hash_algorithm: 'SHA256',
    salt: '',
    min_length: 1,
    max_length: 4,
    include_uppercase: true,
    include_digits: true,
    include_special: false,
    number_of_threads: 6
}

rt_generator = RTGenerator.new(params)

# Override charset
# rt_generator.base_charset = 'abcdefghijklmnopqrstuvwxyz'
# rt_generator.uppercase_charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
# rt_generator.digits_charset = '0123456789'
# rt_generator.special_charset = '!@#$%^&*()_+'

# Benchmark the generation of hashes with current parameters
rt_generator.benchmark(benchmark_time: 10)

# Compute all the hashes and output the results to a file (Text, CSV or JSON)
rt_generator.compute_table(output_path: 'table.csv', overwrite_file: true)

# Compute all the hashes until a specific hash is found
rt_generator.compute_table(hash_to_find: '0bb06b11a595c5ae522f41caccab078890a882a168eca4c69ece3df1c38afb3e')

# Compute all the hashes and output the results (Text, CSV or JSON) until a specific hash is found
rt_generator.compute_table(output_path: 'table.txt', overwrite_file: true, hash_to_find: '0bb06b11a595c5ae522f41caccab078890a882a168eca4c69ece3df1c38afb3e')


