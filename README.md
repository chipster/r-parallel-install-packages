# R parallel install packages


Set of functions to install multiple R packages and their dependencies in parallel. Can be used with CRAN, Bioconductor and HTTP packages. 


## Files

* *parallel-functions.R* 
The beef. Functions to install packages and find their dependencies. More specific description of functions below.

* *smip.R*
SMart Install Packages (SMIP): User friendly interface into install.packages(...) and biocLite(...)
All functions check existence of packages before installation and skip installation if the package already exists. For group of packages, each one is checked individually and only missing ones are installed.
Function also offer more automation compared to original ones, allowing installation of whole repositories, scavenging web pages for packages etc.
For more info and examples for usage in the file.

* *parallel-example.R*
Short example how to use parallel functions with parallel-example.R -script. 
Usage: Takes 3 arguments, package type, file where is list of packages and number of parallel installs.
./Rscript --vanilla ./parallel-example.R cran cran-packs.txt 4  

* *LICENSE*
The MIT license

* *README.md*
This README-text.


##Parallel install functions

parallel-functions.R consists multiple functions, here is short specification for each function and its purpose. 


* *find.cran.dependencies( pkgs, available )* 
*pkgs* = A character vector of the packages 
*available* = A matrix of all available packages and their dependencies. Composed by *available.packages {utils}* -function.

Function finds dependencies for packages and returns list of packages and their dependencies. Uses recursion, so it can find dependencies for packages that are dependencies for another packages. Returns a matrix with all packages needed to install and their dependencies.


* *find.bioc.dependencies( pkgs, bioc.dependencies )* 
*pkgs* = A character vector of the packages 
*bioc.dependencies* = A matrix of all available packages and their dependencies. 

Function finds dependencies for packages and returns list of packages and their dependencies. Uses recursion, so it can find dependencies for packages that are dependencies for another packages. Returns a matrix with all packages needed to install and their dependencies.


* *cran.install.packages( packages, parallel.installs )* 
*packages* = A character vector of the packages to be installed
*parallel.installs* = Number of parallel installs. For example number of CPU cores. 

Installs CRAN packages and their dependencies using parallel socket cluster. It calls other parallel install functions to generate dependency list, send one package to be installed with install.packages() at one node, and wait for result from each node. Uses *parallel* and *method* -packages. Creates log file "cran_install_log.txt".


* *bioc.install.packages( packages, parallel.installs )* 
*packages* = A character vector of the packages to be installed
*parallel.installs* = Number of parallel installs. For example number of CPU cores. 

Installs Bioconductor packages and their dependencies using parallel socket cluster. It calls other parallel install functions to generate dependency list, send one package to be installed with BiocLite() at one node, and wait for result from each node. Uses *parallel*, *method*, *biocLite.R*, *pkgDepTools*, *Biobase* and *Rgraphviz* -packages. Creates log file "bioc_install_log.txt".


* *http.install.packages( packages, parallel.installs )* 
*packages* = A character vector of the packages to be installed
*parallel.installs* = Number of parallel installs. For example number of CPU cores. 

Installs HTTP packages using smart.install.packages -function from SMIP and parallel socket cluster. Calls http.submit() -function which sends one package to be installed with one node. Uses *parallel* and *method* packages. Creates log file "http_install_log.txt".

