# Define path parameters
$BasePath = "Uninitialized" # Caller must specify.

properties {
	$SourcePath = Join-Path $BasePath "Source"
}

# Define the Task to call when none was specified by the caller.
Task Default -depends Build

Task InstallDependencies -description "Installs all dependencies required to execute the tasks in this script." {
	exec { 
		cinst invokemsbuild --version 1.5.17 --confirm
	}
}

Task Build -depends InstallDependencies -description "Compiles all source code." {
	$SolutionPath = Join-Path $SourcePath "Slinqy.sln"

	Write-Host "Building $SolutionPath"

	$MsBuildSucceeded = Invoke-MsBuild $SolutionPath

	Write-Host "MsBuildSucceeded: $MsBuildSucceeded"
}

Task Pull -description "Pulls the latest source from master to the local repo" {
	exec { git pull origin master }
}

Task Push -depends Pull,Build -description "Performs pre-push actions before actually pushing to the remote repo." {
	exec { git push }
}