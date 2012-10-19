#!/usr/bin/env ruby
require 'net/http'
require 'optparse'

DEPARTMENTS = ["10-Sales", "20-Marketing", "30-Finance & Administration", "40-Human Resources", "50-Support", "60-Engineering & Research", "70-Operations", "80-IT & IS", "0-Other"]

class Record
	# This class will define all attributes of an individual record.  For example fname, lname, email...
	# It should also have some class methods that can check if a record exists so as not to duplicate or print all records to the screen/report
	@@domain = ""
	@@domain_is_set = false
	@@counter = 0
	@@records = Array.new 

	attr_accessor :fname, :lname, :fullname, :position, :city, :state, :email1, :email2, :email3, :email4, :department

	def self.domain_is_set
		return @@domain_is_set
	end

	def self.set_domain(domain)
		@@domain = domain
		@@domain_is_set = true
	end

	def self.get_domain
		return @@domain
	end

	def self.counter(num)
		@@counter = @@counter + num
		return @@counter
	end
  
	def self.get_counter
		return @@counter
	end

	def initialize(record_unclean, domain, dept=nil)
		begin
			tempArray = record_unclean.split("=")
			self.lname = tempArray[19].to_s.split(">")[1].split(",")[0].to_s.chomp
			self.fname = tempArray[19].to_s.split(">")[1].to_s.split(",")[1].to_s.split("<")[0].to_s.chomp.gsub(/ /, "").chomp
			self.fullname = self.fname + " " + self.lname
			self.position = tempArray[15].split(">")[1].split("<")[0].to_s.chomp
			self.email1 = self.fname.downcase + "." + self.lname.downcase + "@" + domain
			self.email2 = self.fname.split(//)[0].to_s.downcase + self.lname.downcase + "@" + domain
			self.email3 = self.fname.downcase + self.lname.split(//)[0].to_s.downcase + "@" + domain
			self.state = tempArray[24].split("'")[1].to_s.chomp
			self.city =  tempArray[22].split(">")[1].split("<")[0].to_s.chomp
			self.department = dept.split("-")[1].to_s.chomp
			unless Record.record_exists(self)
				@@records << self
			end
		rescue StandardError => create_record_error
			puts "Couldn't create a new record. #{create_record_error}"
			return create_record_error
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
		puts "Generating the final #{reportname}.csv report"
		begin
			# Try and print all records to the report .csv file
			report = File.new("#{reportname}.csv", "w+")
			report.puts "Full Name\tDepartment\tPosition\tEmail1\tEmail2\tEmail3\tCity\tState"
			@@records.each do |record|
				report.puts record.fullname + "\t" + record.department + "\t" + record.position + "\t" + record.email2 + "\t" + record.email1 + "\t" + record.email3 + "\t" + record.city + "\t" + record.state
			end
			puts "Wrote #{@@records.length} records to #{report.path}\r\n"
			report.close
		rescue StandardError => gen_report_error
			puts "Error generateing the report."
			return gen_report_error
		end
	end

	def self.print_all_records_to_screen
		@@records.each do |record|
			puts record.fullname + "\t" + record.department + "\t" + record.position + "\t" + record.email2 + "\t" + record.email1 + "\t" + record.city + "\t" + record.state
		end
		puts "Dumped #{@@records.length} records"
	end
end

def get_company_domain(response)
	begin
		puts "Retrieving list of company's registered domains" if @options[:verbose]
		domains = Array.new
		response.body.each_line do |line|
			if line.include?("option value=\"") && line.include?(".") && !line.include?("multiple=\"multiple\" size=\"")
				domains << line.split(">")[1].split("<")[0].to_s.chomp
			end
		end
		if domains.length == 1
			puts "Your search only returned one domain.  Using \'#{domains[0]}\' to craft emails."
			Record.set_domain(domains[0])
			return domains[0]
		end
		puts "Your target has #{domains.length} domain/s:\r\n\r\n"
		counter = 1
		domains.each do |domain|
			puts "[#{counter.to_s}] - " + domain
			domains[counter - 1] = "#{counter.to_s}-#{domain}"
			counter = counter + 1
		end
		puts "\r\n"
		print "Enter the number of the domain to use for crafting emails: "
		answer = gets.chomp.to_s
		domains.each do |domain|
			if domain.split("-")[0] == answer
				puts "Using \'#{domain.split("-")[1]}\' to craft emails."
				Record.set_domain(domain.split("-")[1])
				return domain.split("-")[1]
			end
		end
	rescue StandardError => domain_set
		puts "Error setting domain: #{domain_set}"
		return domain_set
	end
end

def get_cookie(http=nil)
	# This method will make the initial get request and set the cookie value to use
	# for the rest of the program
	begin
		# Try to grab cookies	
		resp = http.get("/index.xhtml", {})
		cookie = resp.response['set-cookie']
		headers = { 
			"User-Agent" => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:16.0) Gecko/20100101 Firefox/16.0',
			"Cookie" => cookie,
			"Accept" => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
			"Proxy-Connection" => 'keep-alive',
			"Cache-Control" => 'max-age=0'
		 }
		return headers
	rescue StandardError => cookie_error
		puts "Error getting cookie. #{cookie_error}"
		return cookie_error
	end
end


def search_by_name(http, headers, search)
	#This method will search for a company name provided by the user at runtime
	# It should return an array of strings conaning Company name, number of employees, and jigsaw ID
	puts "Searching for #{search}."
	begin
		# Try and do stuff
		path = "/FreeTextSearch.xhtml?opCode=search&autoSuggested=true&freeText=#{search}"
		resp, data = http.get(path, headers)
		if !resp.body.include?("Company Search Results")
			resp.body.split("\r\n").each do |line|
				if line.include?("view more and edit")
					puts "Jigsaw ID for #{search} is: " + line.split("/")[1].to_s.gsub(/id/, "")
				end
			end
		end
		resp.body.split("</tr>").each do |line|
			if line.include?("type=\'checkbox\' class=\'checkbox\'  name=\'ids\' value=")
				company =  line.split("=")[9].to_s.split("'")[1].to_s.split("'")[0].to_s
				id = line.split("=")[10].to_s.split("/")[1].to_s.gsub(/id/, "")
				employees = line.split("=")[13].split("'")[1].to_s.split("'")[0].to_s
				puts "Jigsaw ID: " + id + "\t- " + company + "\t" + "(" + employees + " employee/s)"
			end
		end
	rescue StandardError => search_error
		puts "Error performing search. #{search_error}"
		return search_error
	end
end


def get_number_of_records(http, headers, id, dept)
	# This module will find the number of records within a givn jigsaw search matching a specified
	# Department.  Example.  There are 133 records in the Finance deparment of company XYZ
	threads = Array.new
	begin
		# Try and do stuff
		threads << Thread.new {
			path = "/SearchContact.xhtml?companyId=#{id}&opCode=showCompDir&dept=#{dept.split("-")[0].to_s}&rpage=1&rowsPerPage=50"
			resp, data = http.get(path, headers)
			domain = get_company_domain(resp) unless Record.domain_is_set
			numrecs = ""
			resp.body.split(";").each do |line|
				numrecs = line.split("+")[1].split('"')[1].to_s.chomp if line.include?("Your search returned") && !line.include?("at least")
			end
			if numrecs.include?(",")
				numrecs = numrecs.gsub(/,/, "")
			end
			Record.counter(numrecs.to_i) unless dept.split("-")[1] == "Other"
			if dept.split("-")[1] == "Other"
				recs = numrecs.to_i - Record.get_counter
				puts "Found #{recs.to_s} records in the #{dept.split("-")[1].to_s} department."
			end
			puts "Found #{numrecs} records in the #{dept.split("-")[1].to_s} department." unless dept.split("-")[1] == "Other"
			pages = get_number_of_pages(numrecs)
			pages.times do |page|
				inline_threads = Array.new
				inline_threads << Thread.new {
					pagenum = page + 1
					get_page_of_records(http, headers, id, dept, pagenum, Record.get_domain)
				}
				inline_threads.each { |thread| thread.join }
			end
			puts "Total records so far: " + Record.get_counter.to_s if @options[:verbose]
		}
		threads.each { |thread| thread.join }
	rescue StandardError => num_error
		puts "Error retrieving number of records #{num_error}"
		return num_error
	end
end 


def get_number_of_pages(numrec)
	# This simply computes the number of records stored in 'numrec' devided evenly by 50
	# Example if numrec == 60 this method will return 2 because we will need to make 2 page requests.  The first showing
	# records 1-50 and the second showing 51-60.
	begin
		answer = (numrec.to_i + 50) / 50 * 50
		return answer / 50
	rescue StandardError => num_recs_error
		puts "Couldn't determine the number of pages. #{num_recs_error}"
		return num_recs_error
	end
end


def get_page_of_records(http, headers, id, dept, pagenum, domain)
	# This method will grab an entire page of records.  And create an instance of the Records class for each record
	threads = Array.new
	begin
		threads << Thread.new {
			# Try and do some stuff
			path = "/SearchContact.xhtml?companyId=#{id}&opCode=showCompDir&dept=#{dept.split("-")[0].to_s}&rpage=#{pagenum.to_s}&rowsPerPage=50"
			resp, data = http.get(path, headers)
			resp.body.split("</tr>").each do |line|
				if line.include?("input type=\'checkbox\'")
					Record.new(line, domain, dept)
				end
			end
		}
		threads.each { |thread| thread.join }
	rescue StandardError => page_rec_error
		puts "Error retreving records from page #{pagenum} for the #{dept.split("-")[1].to_s} department. #{page_rec_error}"
		return page_rec_error
	end
end

unless ARGV.length > 0
        puts "Try ./jigsaw.rb -h\r\n\r\n"
        exit!
end

@options = {}
args = OptionParser.new do |opts|
opts.banner = "Jigsaw 1.2 ( http://www.pentestgeek.com/ - http://hdesser.wordpress.com/ )\r\n"
        opts.banner += "Usage: jigsaw [options]\r\n\r\n"
        opts.banner += "\texample: jigsaw -s Google\r\n\r\n"
        opts.on("-i", "--id [Jigsaw Company ID]", "The Jigsaw ID to use to pull records") { |id| @options[:id] = id }
        opts.on("-s", "--search [Company Name]", "Name of organization to search for") { |search| @options[:search] = search.to_s.chomp }
        opts.on("-r", "--report [Output Filename]", "Name to use for report EXAMPLE: \'-r google\' will generate \'google.csv\'") { |report| @options[:report] = report.to_s.chomp }
	opts.on("-d", "--domain [Domain Name]", "If you want you can specify the domain name to craft emails with") { |domain| @options[:domain] = domain.to_s.chomp }
        opts.on("-v", "--verbose", "Enables verbose output\r\n\r\n") { |v| @options[:verbose] = true }
end
args.parse!(ARGV)


http = Net::HTTP.new('www.jigsaw.com', 80)
headers = get_cookie(http)

if @options[:search]
	search_by_name(http, headers, @options[:search])
elsif @options[:id]
	# Do other stuff
	if @options[:domain]
		if @options[:domain] == ""
			puts "Domain specified with -d cannot be blank.\r\n\r\n"
			exit!
		end
		Record.set_domain(@options[:domain])
	end
	DEPARTMENTS.each do |dept|
		get_number_of_records(http, headers, @options[:id].to_s.chomp, dept)
	end
	if @options[:report]
		Record.write_all_records_to_report(@options[:report])
	else
		Record.print_all_records_to_screen
	end
end
