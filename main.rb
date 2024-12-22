require 'digest'
require_relative 'generator'

params = {
    hash_algorithm: 'SHA256',
    salt: '',
    length: 2,
    include_uppercase: true,
    include_digits: true,
    include_special: true,
    number_of_threads: 10
}

RTGenerator.new(params).compute_table(output_path: 'table.csv')


