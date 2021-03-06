param($installPath, $toolsPath, $package, $project)

function PathToUri([string] $path)
{
    return new-object Uri('file://' + $path.Replace("%","%25").Replace("#","%23").Replace("$","%24").Replace("+","%2B").Replace(",","%2C").Replace("=","%3D").Replace("@","%40").Replace("~","%7E").Replace("^","%5E"))
}

function UriToPath([System.Uri] $uri)
{
    return [System.Uri]::UnescapeDataString( $uri.ToString() ).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)
}

function Get-SolutionDir {
    if($dte.Solution -and $dte.Solution.IsOpen) {
        return Split-Path $dte.Solution.Properties.Item("Path").Value
    }
    else {
        throw "Solution not avaliable"
    }
}

$solutionDir = Get-SolutionDir

$targetsFile = [System.IO.Path]::Combine($toolsPath, 'LessCompiler.targets')

# Need to load MSBuild assembly if it's not loaded yet.
Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

# Grab the loaded MSBuild project for the project
$msbuild = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($project.FullName) | Select-Object -First 1

# Make the path to the targets file relative.
$solutionUri = PathToUri ($solutionDir + "/")
$projectUri = PathToUri $project.FullName
$targetUri = PathToUri $targetsFile

$relativePath = UriToPath $projectUri.MakeRelativeUri($targetUri)

$toolsUri = PathToUri $toolsPath
$toolsRelativePath = UriToPath $solutionUri.MakeRelativeUri($toolsUri)

# Remove previous imports to Calamari.targets
$msbuild.Xml.Imports | Where-Object {$_.Project.ToLowerInvariant().EndsWith("lesscompiler.targets") } | Foreach { 
	$_.Parent.RemoveChild( $_ ) 
}

# Add import to LessCompiler.targets
$import = $msbuild.Xml.AddImport($relativePath)

$import.set_Condition( "Exists('$relativePath')" ) | Out-Null

$project.Object.Refresh()
$project.Save()