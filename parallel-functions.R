## Functions for installing R packages with makeCluster and parallel processing. 



## Create full dependency list for CRAN packets given as a parameter vector. 

# Parameters:
# pgks - Packets to be installed in vector.
# available - Matrix composed with available.packages -function from parallel -packet.
find.cran.dependencies <- function( pkgs, available ) {
	
	## Make dependency list for packages
	dependency.list <- utils:::.make_dependency_list(pkgs, available, recursive = TRUE)
	dependency.list <- lapply(dependency.list, function(x) x[x %in% pkgs])
	
	combined.list <- pkgs
	
	## Create combined package list with dependencies and existing pkgs -list
	combined.list <- pkgs
	
	for( i in seq_along(dependency.list) ) {
		combined.list <- unlist( c( combined.list, dependency.list[[i]] ))
		}
	
	## Remove duplicates
	combined.list <- unique( combined.list )
	
	## If all packages in dependency list are not in pkgs -list, use recursion and add them.
	if( any( !combined.list %in% pkgs ) ) {
	
		## Call function recursively to get the dependencies for all packets 
		dependency.list <- find.cran.dependencies( combined.list, available )
		}
	
	
	## Return dependency list
	return( dependency.list )
	
}



## Create full dependency list for BioC packets given as a parameter vector. 

# Parameters:
# pgks - Packets to be installed in vector.
# bioc.dependencies - Dependency matrix with all packages from repo. Made with makeDepGraph -function.
find.bioc.dependencies <- function( pkgs, bioc.dependencies ) {
	

	## Get dependencies for packages
	dependency.list <- edges(bioc.dependencies)[pkgs]
	
	
	## Create combined package list with dependencies and existing pkgs -list
	combined.list <- pkgs
	
	for( i in seq_along(dependency.list) ) {
		combined.list <- unlist( c( combined.list, dependency.list[[i]] ))
		}
	
	## Remove duplicates
	combined.list <- unique( combined.list )
	
	## If all packages in dependency list are not in pkgs -list, use recursion and add them.
	if( any( !combined.list %in% pkgs ) ) {
	
		## Call function recursively to get the dependencies for rest of the packets
		dependency.list <- find.bioc.dependencies( combined.list, bioc.dependencies )
		}
	
	
	## Return dependency list
	return( dependency.list )
	
}



## Function to install one BioC package on one node
bioc.submit <- function(cluster, node, one.package) {
	parallel:::sendCall(cluster[[node]], biocLite, list(one.package, suppressUpdates=TRUE), tag = one.package)
	}


## Function to install one CRAN package on one node
cran.submit <- function(cluster, node, one.package) {
	parallel:::sendCall(cluster[[node]], install.packages, list(pkgs=one.package, repos=repo.cran), tag = one.package)
	}
	
	
## Function to install one HTTP package on one node
http.submit <- function(cluster, node, one.package) {
	parallel:::sendCall(cluster[[node]], smart.install.packages, list(url.package=one.package), tag = one.package)
	}



## While-loop function to check if nodes & packages are ready
# and install them with submit -function. 
# Used by cran.install.packages and bioc.install.packages 

install.rest.of.packages <- function( dependency.list, packages.done, available.nodes, cluster, packages, type ) {
	while(length(packages.done) < length(packages)) {
	
		# Get one result for sendCall from node
		result <- parallel:::recvOneResult(cluster)
		
		# Add node for available workers
		available.nodes <- c(available.nodes, result$node)
	
		# Add package to done and remove it from DL
		packages.done <- c(packages.done, result$tag)

		# Add package to OK -list (OK if dependencies are done)
		dependencies.ok <- unlist(lapply(dependency.list, function(x) all(x %in% packages.done) ))

		# If installed.packages is still empty, start loop from beginning
		if (!any(dependencies.ok)) next
	
		# Get packets that has their dependencies ready
		dependencies.ready <- names(dependency.list)[dependencies.ok]
		
		# How many packages are ready to be installed and how many available workers
		packages.to.install <- min(length(dependencies.ready), length(available.nodes)) # >= 1
	
		# Use submit function for each pkg to sendCall to nodes
		if ( packages.to.install != 0 ) {
			for (i in 1:packages.to.install) 
			{
				if( type == "cran" ) {
					cran.submit(cluster, available.nodes[i], dependencies.ready[i])
				} else if( type == "bioc" ) {
					bioc.submit(cluster, available.nodes[i], dependencies.ready[i])
				}
			}
		}
			
	
		# Remove used nodes from available workers
		available.nodes <- available.nodes[-(1:packages.to.install)]
	
		# Remove packages which was sent to workers
		dependency.list <- dependency.list[!names(dependency.list) %in% dependencies.ready[1:packages.to.install]]

	}
}



## Function to install multiple CRAN packages using parallel instances. 
# Parameters:
# packages - Packages to be installed in vector
# parallel.installs - Number of parallel installs
cran.install.packages <- function( packages, parallel.installs ) {

	## Load needed packages
	require(parallel)
	require(methods)

	## Remove old logfile
	unlink("cran_install_log.txt")

	## Set up available packages and get their dependencies 
	available <- available.packages()
	dependency.list <- find.cran.dependencies( packages, available )
	
	# if amount of nodes is smaller than packages to be installed..
	parallel.installs <- min(parallel.installs, length(names(dependency.list)))

	## Create local cluster
	cluster <- makeCluster(parallel.installs, type = "FORK", outfile = "cran_install_log.txt")

	## How many dependencies are for each package
	dependencies <- sapply(dependency.list, length)

	## Packages that are ready to be installed (have no dependencies)
	packages.ready <- names(dependency.list[dependencies == 0L])

	## Packages already installed
	packages.done <- character()

	## How many packages are ready to be installed
	waiting.packages <- length(packages.ready)
	
	## For loop to install n packages 
	for (i in 1:min(waiting.packages, parallel.installs)) {
		cran.submit(cluster, i, packages.ready[i])
		}
	
	## Remove packages that are already ready to be installed
	dependency.list <- dependency.list[!names(dependency.list) %in% packages.ready[1:min(waiting.packages, parallel.installs)]]

	## Available workers
	available.nodes <- if(waiting.packages < parallel.installs) (waiting.packages+1L):parallel.installs else integer()
	
	## Call function to install rest of the packets
	install.rest.of.packages( dependency.list, packages.done, available.nodes, cluster, packages, type="cran" )
	
	## Stop cluster
	stopCluster(cluster)
	
}
	
	

## Function to install multiple BioC packages using parallel instances. 
# Parameters:
# packages - Packages to be installed in vector
# parallel.installs - Number of parallel installs
bioc.install.packages <- function( packages, parallel.installs ) {

	## Load needed packages
	require(parallel)
	require(methods)
	source("http://bioconductor.org/biocLite.R")
	biocLite("pkgDepTools")
	biocLite("Biobase")
	biocLite("Rgraphviz")

	library("Biobase")
	library("Rgraphviz")
	library("pkgDepTools")


	## Remove old logfile
	unlink("bioc_install_log.txt")

	## Set up available packages and get their dependencies 
	bioc.repo <- biocinstallRepos()
	bioc.dependencies <- makeDepGraph(bioc.repo, type="source", dosize=FALSE)

	dependency.list <- find.bioc.dependencies( packages, bioc.dependencies )
	
	## How many dependencies are for each pkg
	dependencies <- sapply(dependency.list, length)

	# if amount of nodes is smaller than packages to be installed..
	parallel.installs <- min(parallel.installs, length(names(dependency.list)))

	## Create local cluster
	cluster <- makeCluster(parallel.installs, type = "FORK", outfile = "bioc_install_log.txt")

	## Packages that are ready to be installed (have no dependencies)
	packages.ready <- names(dependency.list[dependencies == 0L])

	## Packages already installed
	packages.done <- character()

	## How many packages are ready to be installed
	waiting.packages <- length(packages.ready)

	## For loop to install n packages 
	for (i in 1:min(waiting.packages, parallel.installs)) {
		bioc.submit(cluster, i, packages.ready[i])
		}
	
	## Remove packages that are already ready to be installed
	dependency.list <- dependency.list[!names(dependency.list) %in% packages.ready[1:min(waiting.packages, parallel.installs)]]

	## Available workers
	available.nodes <- if(waiting.packages < parallel.installs) (waiting.packages+1L):parallel.installs else integer()
	
	## Call function to install rest of the packets
	install.rest.of.packages( dependency.list, packages.done, available.nodes, cluster, packages, type="bioc" )
	
	## Stop cluster
	stopCluster(cluster)	

}


## Function to install multiple HTTP packages using parallel instances. 
# Parameters:
# packages - Packages to be installed in vector
# parallel.installs - Number of parallel installs
## Load needed packages
http.install.packages <- function( packages, parallel.installs ) {

	require(parallel)
	require(methods)

	## Remove old logfile
	unlink("http_install_log.txt")

	# if amount of nodes is smaller than packages to be installed..
	parallel.installs <- min(parallel.installs, length(packages))

	## Create local cluster
	cluster <- makeCluster(parallel.installs, type = "FORK", outfile = "http_install_log.txt")

	## Packages already installed
	packages.done <- character()

	## How many packages are ready to be installed
	waiting.packages <- length(packages)

	## For loop to install n packages 
	for (i in 1:parallel.installs) {
		http.submit(cluster, i, packages[i])
		}

	## Remove packages that were sent to cluster
	packages <- packages[-(1:parallel.installs)]

	## Available workers
	available.nodes <- if(waiting.packages < parallel.installs) (waiting.packages+1L):parallel.installs else integer()

	## While loop to check if nodes & packages are ready
	# and install them with submit -function.
	while(length(packages.done) < waiting.packages) {

		# Get one result for sendCall from node
		result <- parallel:::recvOneResult(cluster)
	
		# Add node for available workers
		available.nodes <- c(available.nodes, result$node)
	
		# Add package to done and remove it from DL
		packages.done <- c(packages.done, result$tag)
		

		# How many packages are ready to be installed and how many available workers
		packages.to.install <- min(waiting.packages, length(available.nodes)) # >= 1
	
		# Use http.submit function for each pkg to sendCall to nodes
		if( packages.to.install != 0 ) {
			for (i in 1:packages.to.install) {
				http.submit(cluster, available.nodes[i], packages[i])
			}
		}
		
		# Remove used nodes from available workers
		available.nodes <- available.nodes[-(1:packages.to.install)]
		
		# Remove packages that was sent to nodes
		packages <- packages[-(1:packages.to.install)]
		
	}
	## Stop cluster
	stopCluster(cluster)
	
}