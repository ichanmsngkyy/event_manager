# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

puts 'Event Manager Initialized'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_number(number)
  digits = number.gsub(/\D/, '')
  if digits.length == 10
    digits
  elsif digits.length == 11 && digits[0] == '1'
    digits [1..]
  else
    'Bad number'
  end
end

def hour(time)
  DateTime.strptime(time, '%m/%d/%y %H:%M').hour
end

def extract_day(day)
  DateTime.strptime(day, '%m/%d/%y %H:%M').wday
end

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hourly_count = Hash.new(0)
day_count = Hash.new(0)

day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday]

contents.each do |row|
  id = row[0]
  name = row [:first_name]

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  number = clean_number(row[:homephone])
  time = hour(row[:regdate])
  day = extract_day(row[:regdate])

  hourly_count[time] += 1
  day_count[day] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts "#{name} (Phone: #{number}, Registered at Hour: #{time}, Day: #{day_names[day]})"
end

puts 'Peak Registration Hours'
hourly_count.sort_by {|_hour,count| -count}.each do |hour,count|
  puts "Hour #{hour}: #{count} registrations"
end


puts 'Peak Registration Day'
day_count.sort_by {|_day,count| -count}.each do |day, count|
  puts "Day #{day_names[day]}: #{count} registrations"
end
