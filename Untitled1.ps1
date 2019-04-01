$testinput = "n"
$confirmation = $Null

$confirmation = Read-Host "Is it ok to proceed?"
if ($confirmation -ne $Null){
if ($testinput -eq "y") {

Write-Host "It is equal to 'y'"

$testinput

} else {

Write-Host "It is not equal to Y"

}

}

else {

Write-Host "This was fucked up"
}
