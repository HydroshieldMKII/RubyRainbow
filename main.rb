require_relative 'rtgenerator'

params = {
    hash_algorithm: 'SHA256',
    salt: '',
    min_length: 1,
    max_length: 3,
    include_uppercase: true,
    include_digits: true,
    include_special: false,
    number_of_threads: 6
}

rt_generator = RTGenerator.new(params)
rt_generator.compute_table(output_path: 'table.txt', overwrite_file: true)

rt_generator.compute_table(hash_to_find: '0bb06b11a595c5ae522f41caccab078890a882a168eca4c69ece3df1c38afb3e')


