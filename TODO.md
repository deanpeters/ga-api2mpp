Description
============

This document serves as an unofficial location to enumerate backlog requests for bugs and feature requests.

## Features ##

### Perl ###

* employ a getops module w/perldoc error handling
* figure out how to do CDATA blocks with the description & title fields using XML::FeedPP
* explore the possibility of employing the Perl Template Toolkit to allow cool formatting of output
* See what can be done about getting filtering to work in the context of Net::Google::Analytics, possibly with a hash of arrays?

### Python ###

* employ a getops module w/python documentation
* I don't know if PyRSS2Gen is the best choice for this script, investigate other similar solutions

### Both ###

* Rather than ask for a profileID, see if there is an easier way to get it by iterating through the available IDs
* Use a YAML file to provide comprehensive configuration and settings for both versions
* employ a 'try 5 times' to reach the API, the duration between each iteration gets longer until success or 5th fail
* See what can be done with regard to date ranges, so aside from ordinal date, use terms like "this month" or "last week"
* more robust error handling, catch & throw more
* employ utm filtering for inbound data
* employ utm tracking for outbound links, such as ?utm_source=ga-app2mpi&utm_medium=rss-widget&utm_campaign=most-popular-pages
# once utm tracking is employed, then filter on the same utms &/or others?
* do we want to bring in a real-deal CSV module to process the files? 
* do we want to explore a excel spreadsheet module?

## Bugs ##

### Perl ###

* don't worry, I'm sure something will come up

### Python ###

* see what I wrote under perl bugs

### Both ###

* Daggum UTF-8 & all the fun characters we get to work & play with