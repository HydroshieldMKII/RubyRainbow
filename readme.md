# RTGenerator

RTGenerator is a Ruby-based tool for generating and benchmarking rainbow tables for hash algorithms. It supports customizable character sets, multithreading, and output formats like JSON, CSV, and text files.

## Features

- Supports popular hash algorithms: MD5, SHA1, SHA256, SHA384, SHA512, RMD160.
- Customizable character sets (base, uppercase, digits, special characters).
- Multithreaded hash computation.
- Progress bar with real-time updates.
- Output results in JSON, CSV, or plain text formats.
- Benchmarking capabilities for performance analysis.

---

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
  - [Initial Setup](#initial-setup)
  - [Parameters](#parameters)
  - [Benchmarking](#benchmarking)
  - [Compute Rainbow Table](#compute-rainbow-table)
  - [Advanced Configuration](#advanced-configuration)
  - [File Formats](#file-formats)
  - [Example](#example)
  - [Dependencies](#dependencies)

## Installation

1. Install Ruby on your system if not already installed.
2. Clone or download this repository.
3. Install the required gems by running:
   ```bash
   gem install thread timeout digest json csv parallel ruby-progressbar
    ```
4. Run the script with the following command to test the installation:
    ```bash
    ruby main.rb
    ```

## Usage

### Initial Setup

Create a new instance of the RTGenerator class by providing required parameters:

```ruby
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
```

### Parameters

| Parameter          | Type    | Description                              | Example Value |
|--------------------|---------|------------------------------------------|---------------|
| hash_algorithm     | String  | Hash algorithm to use. Supported: MD5, SHA1, etc. | 'SHA256'      |
| salt               | String  | Salt to prepend to hashes.               | 'mysalt'      |
| min_length         | Integer | Minimum length of generated strings.     | 1             |
| max_length         | Integer | Maximum length of generated strings.     | 3             |
| include_uppercase  | Boolean | Include uppercase letters in charset.    | true          |
| include_digits     | Boolean | Include digits in charset.               | true          |
| include_special    | Boolean | Include special characters in charset.   | true          |
| number_of_threads  | Integer | Number of threads for parallel processing. | 6             |

### Benchmarking

Measure hash generation performance with the benchmark method:

```ruby
rt_generator.benchmark(benchmark_time: 10)
```

**Output:**
- Elapsed time
- Total hashes computed
- Hashes computed per second and per minute

### Compute Rainbow Table

Generate a rainbow table and save to a file:

```ruby
rt_generator.compute_table(output_path: 'table.csv', overwrite_file: true)
```
Supported output formats:
- `.txt`: Plain text with hash and plaintext pairs.
- `.csv`: CSV file with hash and plaintext columns.
- `.json`: JSON file with hash-to-plaintext mappings.

Find a specific hash in the generated table:

```ruby
hash, value = rt_generator.compute_table(hash_to_find: 'your_hash_here')
puts "Hash found: #{hash}:#{value}"
```

### Advanced Configuration

Override default character sets:

```ruby
    rt_generator.base_charset = ('x'..'z').to_a
    rt_generator.uppercase_charset = ('M'..'P').to_a
    rt_generator.digits_charset = ('4'..'7').to_a
    rt_generator.special_charset = ['@', '#', '$']
```

### Example

```ruby
rt_generator = RTGenerator.new({
    hash_algorithm: 'SHA256',
    salt: 'mysalt',
    min_length: 1,
    max_length: 3,
    include_uppercase: false,
    include_digits: true,
    include_special: false,
    number_of_threads: 4
})

rt_generator.benchmark(benchmark_time: 5)
rt_generator.compute_table(output_path: 'rainbow_table.json', overwrite_file: true)
rt_generator.compute_table(hash_to_find: 'your_hash_here') #=> 'your_hash_here':'plaintext'
```
