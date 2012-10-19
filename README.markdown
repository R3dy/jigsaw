Jigsaw.rb 
=========
Is a simple ruby script for enumerating information about a company's employees.
It is useful for Social Engineering or Email Phishing
Collaborative project between Royce Davis (R3dy) and humble-desser 

Contact: royce.e.davis@gmail.com

Help:
-----
	$ ./jigsaw -h
	Jigsaw 1.2 ( http://www.pentestgeek.com/ - http://hdesser.wordpress.com/ )
	Usage: jigsaw [options]

		example: jigsaw -s Google

    		-i, --id [Jigsaw Company ID]     The Jigsaw ID to use to pull records
    		-s, --search [Company Name]      Name of organization to search for
    		-r, --report [Output Filename]   Name to use for report EXAMPLE: '-r google' will generate 'google.csv'
    		-d, --domain [Domain Name]       If you want you can specify the domain name to craft emails with
    		-v, --verbose                    Enables verbose output
Example1:
---------
	$ ./jigsaw -s Google
	Your search returned more then one company
	Jigsaw ID: 215043	- Google, Inc.	6,627 employees.
	Jigsaw ID: 224667	- Google Postini Services	149 employees.
	Jigsaw ID: 439035	- AdMob Google Inc	2 employees.
	Jigsaw ID: 5032028	- Google Inc	1 employees.


Example2:
---------
	$ ./jigsaw.rb -i 215043 -r google -d google.com
	Found 1047 records in the Sales department.
	Found 666 records in the Marketing department.
	Found 870 records in the Finance & Administration department.
	Found 249 records in the Human Resources department.
	Found 150 records in the Support department.
	Found 1282 records in the Engineering & Research department.
	Found 354 records in the Operations department.
	Found 1171 records in the IT & IS department.
	Found 300 records in the Other department.
	Generating the final google.csv report
	Wrote 6079 records to google.csv
