#!/usr/bin/env ruby
#Author - R3dy - http://www.pentestgeek.com
#This script grabs Employee Names & Titles from www.jigsaw.com
# 2012, June 7th.  Edit - Now grabs all records from jigsaw, not just first 50
#   Example Syntas:
#    ./jigsaw.rb CompanyName
require 'net/http'
require 'optparse'


THREADS = Array.new
DEPARTMENTS = ["10-Sales", "20-Marketing", "30-Finance & Administration", "40-Human Resources", "50-Support", "60-Engineering & Research", "70-Operations", "80-IT & IS", "0-Other"]


options = {}
args = OptionParser.new do |opts|
	opts.banner = "Jigsaw 1.0 ( http://www.pentestgeek.com )\r\n"
        opts.banner += "Usage: jigsaw [options]\r\n\r\n"
        opts.banner += "\texample: jigsaw -s Google\r\n\r\n"
        opts.on("-i", "--id [Jigsaw Company ID]", "The Jigsaw ID to use to pull records") { |id| options[:id] = id }
        opts.on("-s", "--search [Company Name]", "Name of organization to search for") { |company| options[:company] = company }
        opts.on("-r", "--report [Output Filename]", "Name to use for report EXAMPLE: \'-r google\' will generate \'google.csv\'") { |report| options[:report] = report }
        opts.on("-v", "--verbose", "Enables verbose output\r\n\r\n") { |v| options[:verbose] = v }
end
args.parse!(ARGV)


def get_target_id(target)
	companyId = ""
	uri = URI('http://www.jigsaw.com/FreeTextSearch.xhtml')
	params = { :opCode => "search", :autoSuggested => "true", :freeText => target }
	uri.query = URI.encode_www_form(params)
	response = Net::HTTP.get_response(uri)
	unless response.body.include?("Company Search Results")
		response.body.split("\r\n").each do |line|
			if line.include?("view more and edit")
				companyId = line.split("/")[1].to_s.gsub(/id/, "")
			end
		end
		return companyId
    	end
	puts "Your search returned more then one company\r\n"
	get_company_list(response.body)
end


def get_company_list(body)
	body.split("</tr>").each do |line|
		if line.include?("type=\'checkbox\' class=\'checkbox\'  name=\'ids\' value=")
			company =  line.split("=")[9].to_s.split("'")[1].to_s.split("'")[0].to_s
			id = line.split("=")[10].to_s.split("/")[1].to_s.gsub(/id/, "")
			employees = line.split("=")[13].split("'")[1].to_s.split("'")[0].to_s
			puts "Jigsaw ID: " + id + "\t- " + company + "\t" + employees + " employees."
		end
	end
	exit!
end


def get_employees(id, options, dept=nil)
	uri = URI('http://www.jigsaw.com/SearchContact.xhtml')
	params = { :companyId => id, :opCode => "showCompDir", :dept => dept.split("-")[0].to_s, :rpage => "1", :rowsPerPage => "50" }
	uri.query = URI.encode_www_form(params)
	response = Net::HTTP.get_response(uri)
	domain = get_company_domain(response)
	pages = get_number_of_pages(get_number_of_records(response.body)) / 50
	if options[:verbose]
		if dept.split("-")[1].to_s.chomp == "Other"
			recs = get_number_of_records(response.body)
			recs = recs - Record.get_counter
			puts "Found #{recs} records in #{dept.split("-")[1].to_s.chomp}" unless !get_number_of_records(response.body)
		else
			puts "Found #{get_number_of_records(response.body).to_s} records in #{dept.split("-")[1].to_s.chomp}\r\n" unless !get_number_of_records(response.body)\
		end
	end
	Record.counter(get_number_of_records(response.body)) unless dept.split("-")[1].to_s.chomp == "Other"
	pages.times do |page|
		THREADS << Thread.new {
			page = page + 1
			get_each_page(page.to_s, id, domain, options, dept)
		}
	end
end


def get_company_domain(response)
	domain = ""
	response.body.each_line do |line|
		if line.include?("option value=\"") && line.include?(".") && !line.include?("multiple=\"multiple\" size=\"")
			domain = line.split(">")[1].split("<")[0].to_s
			break
		end
	end
	return domain
end


def get_each_page(page, id, domain, options, dept=nil)
	onerec = ""
	THREADS << Thread.new {
	#puts "Extracting individual employee records from page #{page.to_s}\r\n" if options[:verbose]
	uri = URI('http://www.jigsaw.com/SearchContact.xhtml')
	params = { :companyId => id.chomp, :opCode => "showCompDir", :rpage => page, :rowsPerPage => "50", :dept => dept.split("-")[0].to_s }
	uri.query = URI.encode_www_form(params)
	response = Net::HTTP.get_response(uri)
	response.body.split("/tr").each do |line|
		if line.include?("input type=\'checkbox\'")
			Record.new(line, domain, dept)
		end
	end  
	}
end


def get_number_of_pages(records)
	recordsroundedup = (records.to_i + 100) / 100 * 100
	return recordsroundedup
end


def get_number_of_records(body)
	recordstrue = ""
	body.split(";").each do |line|
		recordstrue = line.split("+")[1].split('"')[1].to_s.chomp if line.include?("Your search returned") && !line.include?("at least")
	end
	if recordstrue.include?(",")
		recordstrue = recordstrue.gsub(/,/, "")
	end
	if recordstrue == ""
		puts "Dit not find any records\r\n"
		exit!
	else
		return recordstrue.chomp.to_i
	end
end


class Record 
	@@counter = 0
	@@records = Array.new 
	attr_accessor :fname, :lname, :fullname, :position, :city, :state, :email1, :email2, :email3, :email4, :department

	def self.counter(num)
		@@counter = @@counter + num
		return @@counter
	end
  
	def self.get_counter
		return @@counter
	end

	def initialize(record_unclean, domain, dept=nil)
		tempArray = record_unclean.split("=")
		self.lname = tempArray[19].to_s.split(">")[1].split(",")[0].to_s.chomp
		self.fname = tempArray[19].to_s.split(">")[1].to_s.split(",")[1].to_s.split("<")[0].to_s.chomp.gsub(/ /, "").chomp
		self.fullname = self.fname + " " + self.lname
		self.position = tempArray[15].split(">")[1].split("<")[0].to_s.chomp
		self.email1 = self.fname.downcase + "." + self.lname.downcase + "@" + domain
		self.email2 = self.fname.split(//)[0].to_s.downcase + self.lname.downcase + "@" + domain
		self.state = tempArray[24].split("'")[1].to_s.chomp
		self.city =  tempArray[22].split(">")[1].split("<")[0].to_s.chomp
		self.department = dept.split("-")[1].to_s.chomp
		unless Record.record_exists(self)
			@@records << self
		end
	end
  
	def self.record_exists(record)
		@@records.each do |rec|
			if rec.fullname == record.fullname && rec.position == record.position
				return true
			end
		end
		return false
	end 
  
	def self.write_all_records_to_report(reportname)
		report = File.new("#{reportname}.csv", "w+")
		report.puts "First Name\tLast Name\tFull Name\tDepartment\tPosition\tEmail1\tEmail2\tCity\tState"
		@@records.each do |record|
			report.puts record.fname + "\t" + record.lname + "\t" + record.fullname + "\t" + record.department + "\t" + record.position + "\t" + record.email2 + "\t" + record.email1 + "\t" + record.city + "\t" + record.state
		end
		puts "Wrote #{@@records.length} records to #{report.path}\r\n"
		report.close
	end

	def self.print_all_records_to_screen
		@@records.each do |record|
			puts record.fullname + "\t" + record.department + "\t" + record.position + "\t" + record.email2 + "\t" + record.email1 + "\t" + record.city + "\t" + record.state
		end
		puts "Dumped #{@@records.length} records"
	end

end


if options[:company]
	puts "Jigsaw ID for #{options[:company]} is: " + get_target_id(options[:company])
elsif options[:id]
	DEPARTMENTS.each { |dept| 
		get_employees(options[:id].to_s.chomp, options, dept) 
	}
	THREADS.each { |thread| thread.join }
	Record.print_all_records_to_screen unless options[:report]
	Record.write_all_records_to_report(options[:report]) unless !options[:report]
end
