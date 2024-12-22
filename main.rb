require 'digest'
require_relative 'generator'

params = {
    hash_algorithm: 'SHA256',
    salt: 'salty',
    length: 8,
    include_uppercase: true,
    include_digits: true,
    number_of_threads: 4
}

RTGenerator.new(params).benchmark


