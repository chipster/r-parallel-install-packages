## Usage example of parallel-functions.R 
# Takes 3 arguments, package type, file where is list of packages and number of parallel installs
# ./Rscript --vanilla ./parallel-example.R cran cran-packs.txt 4 


# Determine the path of the executing script
initial.options <- commandArgs(trailingOnly = FALSE)
file.arg.name <- "--file="
script.name <- sub(file.arg.name, "", initial.options[grep(file.arg.name, initial.options)])
script.basename <- dirname(script.name)
# Make path name absolute
script.basename <- normalizePath(script.basename)

# Load SMIP and parallel functions
source(paste(script.basename, "/smip.R", sep=""));
source(paste(script.basename, "/parallel-functions.R", sep=""));

## Set repos

repo <- getOption("repos")
repo["CRAN"] <- "http://ftp.sunet.se/pub/lang/CRAN"
options(repos=repo)

repo.cran <- "http://ftp.sunet.se/pub/lang/CRAN"

options( error = dump.frames  )

## Read command line arguments to file
arguments <- commandArgs(trailingOnly = TRUE)

## Read installation type
type <- arguments[1]

## Load packages to be installed
packages <- readLines(arguments[2])

## Set number of parallel installs
parallel.installs <- as.numeric(arguments[3])

if( type == "cran" ) {

	smart.install.packages(package="tcltk", mirror=repo.cran)
	cran.install.packages( packages, parallel.installs )
	
} else if( type == "bioc" ) {

	bioc.install.packages( packages, parallel.installs )
	 
} else if( type == "http" ) {

	http.install.packages( packages, parallel.installs )
				
} else {
	print("Error: unsupported package type")
}

	
	
	