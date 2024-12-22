require_relative 'rtgenerator'

params = {
    hash_algorithm: 'SHA256',
    salt: '',
    length: 4,
    include_uppercase: true,
    include_digits: true,
    include_special: true,
    number_of_threads: 10
}

raibow_table_generator = RTGenerator.new(params)

# raibow_table_generator.benchmark
raibow_table_generator.compute_table(output_path: 'table.txt')


