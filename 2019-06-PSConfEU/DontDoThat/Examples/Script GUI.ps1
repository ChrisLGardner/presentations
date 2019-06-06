[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

#######################
# Gets all files in target
# location and all files
# one layer below that.
# Returns array of all files
# including folder if needed
######################
function Get-Folders {

	param (
		[string]$FolderLocation = $args[0]
	)
	$Folders = Get-ChildItem $FolderLocation
	$AllItems = @()

	Foreach ($item in $Folders) {
		if((Get-Item ($FolderLocation + $item.Name)) -is [System.IO.DirectoryInfo]) {
			Get-ChildItem ($FolderLocation + $item) | Foreach-Object {
				if (($_.Name).SubString(($_.Name).length-3) -eq "ps1") {
					$AllItems += ($item.Name + "\" + $_.Name)
				}
			}
		}
		else {
			if (($item.Name).SubString(($item.Name).length-3) -eq "ps1") {
				$AllItems +=($item.Name)
			}
		}
	}

	return $AllItems
}

###################
# Produces a File Dialog
# and limits to csv and text
#
# returns file path selected
###################
Function Get-FileLocation {
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = "C:\"
	$OpenFileDialog.filter = "Csv Files (*.csv) | *.csv| Text Files (*.txt)|*.txt"
	$OpenFileDialog.ShowDialog() | Out-Null
	return $OpenFileDialog.filename
}

###########################
# When using the calendar
# gets the date to populate
# the textbox
############################
Function Get-DateFromCalendar {
	foreach ($control in $objForm.Controls) {
		if ($control.Name -match 'Panel') {
			foreach ($subcontrol in $control.Controls) {
				if($subcontrol.Name -match 'Calendar') {
					return $subcontrol.SelectionStart.ToShortDateString()
				}
			}
		}
	}

}

##########################
# Gets Parameter names from
# script file at path provided
#
#########################
Function Get-Params {
	param (
		[string]$PathToScript = $args[0]
	)
    $ParamsNames = @()
	$Script = Get-Command $PathToScript
	$Script.ParameterSets[0] | select -ExpandProperty parameters | Foreach-Object {
		if ($_.Position -gt -1) {
			$ParamsNames += $_.Name
		}
	}
    return $ParamsNames
}

######################
# Hides all panels to
# ensure only selected
# script panel is visible
#
######################
Function Clear-Panels {
    foreach ($control in $objForm.Controls) {
        if ($control.Name -match 'Panel' -and $control.visible -eq $true) {
            #$control.Visible = $false
            $objForm.Controls.Remove($Control)

        }

    }

}

##########################
# Runs script with correct
# parameters pulled from
# text boxes on form
#
#########################
Function Run-Script {

    $ArrayOfVariables =@()
    $ParamsNames = Get-Params ($FolderLocation + $ScriptSource[$ComboBox.SelectedIndex])
    foreach ($control in $objForm.Controls) {
        if ($control.Name -match 'Panel') {
            foreach ($subcontrol in $control.Controls) {
                if($subcontrol.Name -match 'TextBox') {
                    $ArrayOfVariables += $subcontrol.Text
                }
            }
        }
    }
    $ScriptCommandLine = ($FolderLocation + $ScriptSource[$ComboBox.SelectedIndex])
    For ($i = 0; $i -lt $ArrayOfVariables.length; $i++) {
        $ScriptCommandLine += " -" + $ParamsNames[$i] + " " + $ArrayOfVariables[$i]
    }
    Invoke-Expression $ScriptCommandLine
}

###############################
# Creates each label and box for
# the parameters for the script
# that is selected.
#
# takes selected script path as param
###############################
Function Show-ParamsBoxes {
    param (
		[string]$PathToScript = $args[0]
	)

	$ParamsNames = Get-Params $PathToScript
	$ParamButton = $null
	$ParamDate = $null
	$ParamBoxes = @()
	$ParamLabels = @()
    $count = 0
	Foreach ($param in $ParamsNames) {
		if ($Param -match "Path") {
			$ParamLabels += New-Object System.Windows.Forms.Label
			$ParamLabels[$count].Text = "Browse to required file"
			$ParamLabels[$count].Size = $SizeObject

			$ParamBoxes += New-Object System.Windows.Forms.TextBox
			$ParamBoxes[$count].Name = ($param + "TextBox")
            $ParamBoxes[$count].Size = $SizeObject

            $ParamButton = New-Object System.Windows.Forms.Button
            $ParamButton.Text = "Browse"
            $ParamButton.Add_Click({
                $FileLocation=Get-FileLocation;
                foreach ($control in $objForm.Controls) {
                    if ($control.Name -match 'Panel') {
                        foreach ($subcontrol in $control.Controls) {
                            if($subcontrol.Name -eq 'PathTextBox') {
                                $subcontrol.Text = $FileLocation
                            }
                        }
                    }
                }
            })
		}
		elseif ($Param -match "Date") {
			$ParamLabels += New-Object System.Windows.Forms.Label
			$ParamLabels[$count].Text = "Enter date required (dd/mm/yyyy):"
			$ParamLabels[$count].Size = $SizeObject

			$ParamBoxes += New-Object System.Windows.Forms.TextBox
			$ParamBoxes[$count].Name = ($param + "TextBox")
            $ParamBoxes[$count].Size = $SizeObject

			$ParamDate = New-Object System.Windows.Forms.MonthCalendar
			$ParamDate.ShowTodayCircle = $false
			$ParamDate.MaxSelectionCount = 1
			$ParamDate.MaxDate = Get-Date
			$ParamDate.Name = ($param + "Calendar")
			$ParamDate.Add_DateSelected({
				$DateValue = Get-DateFromCalendar
				foreach ($control in $objForm.Controls) {
                    if ($control.Name -match 'Panel') {
                        foreach ($subcontrol in $control.Controls) {
                            if($subcontrol.Name -match 'DateTextBox') {
                                $subcontrol.Text = $DateValue
                            }
                        }
                    }
                }
            })
			$ParamDate.Add_DateChanged({
				$DateValue = Get-DateFromCalendar
				foreach ($control in $objForm.Controls) {
                    if ($control.Name -match 'Panel') {
                        foreach ($subcontrol in $control.Controls) {
                            if($subcontrol.Name -match 'DateTextBox') {
                                $subcontrol.Text = $DateValue
                            }
                        }
                    }
                }
            })
		}
		else {
			$ParamLabels += New-Object System.Windows.Forms.Label
			$ParamLabels[$count].Text = "Enter value for " + $param + ":"
			$ParamLabels[$count].Size = $SizeObject

			$ParamBoxes += New-Object System.Windows.Forms.TextBox
            $ParamBoxes[$count].Name = $param + "TextBox"
			$ParamBoxes[$count].Size = $SizeObject
		}
    $count += 1
	}
	$Panel = New-Object System.Windows.Forms.FlowLayoutPanel
	$Panel.AutoSize = $True
	$Panel.FlowDirection = "TopDown"
    $Panel.Name = "ParamPanel"
	$Panel.Location = New-Object System.Drawing.Size(20, 150)
	$count2 = 0
	Foreach ($param in $ParamLabels) {
		$Panel.Controls.Add($ParamLabels[$count2])
		$Panel.Controls.Add($ParamBoxes[$count2])
    $count2 += 1
	}
    if ($ParamButton) {
        $Panel.Controls.Add($ParamButton)
    }
	if ($ParamDate) {
		$Panel.Controls.Add($ParamDate)
	}
	return $Panel
}

#######################
# Some variables used throughout
# the application are
# defined here
########################
New-PSDrive -Name "ScriptLocation" -PSProvider FileSystem -Root C:\Source\github
$FolderLocation = "ScriptLocation:\"
$ScriptSource = Get-Folders -FolderLocation $FolderLocation
$SizeObject = New-Object System.Drawing.Size(200,20)

###########################################################
#
# Beginning of form layout
#
###########################################################
$objForm = New-Object System.Windows.Forms.Form
$objForm.Text = "Script Selection Form"
$objForm.Size = New-Object System.Drawing.Size(300,500)
$objForm.StartPosition = "CenterScreen"

$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter")
    {$x=$objTextBox.Text;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape")
    {$objForm.Close()}})

################################OTHER CONTROLS HERE#####################################
$ComboBox = New-Object System.Windows.Forms.ComboBox
$ComboBox.DropDownStyle = "DropDownList"
$ComboBox.Location = New-Object System.Drawing.Size(40,60)
$ComboBox.Size = $SizeObject
foreach($file in $ScriptSource) {
	$ComboBox.Items.Add($file)
}
$ComboBox.Add_SelectedIndexChanged({
    Clear-Panels
    $NewPanel = Show-ParamsBoxes ($FolderLocation + $ScriptSource[$ComboBox.SelectedIndex])
    $objForm.Controls.Add($NewPanel)
})
$objForm.Controls.Add($ComboBox)

$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Location = New-Object System.Drawing.Size(70,100)
$RunButton.Size = New-Object System.Drawing.Size(75,23)
$RunButton.Text = "Run Script"
$RunButton.Add_Click({Run-Script})
$objForm.Controls.Add($RunButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(155,100)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20)
$objLabel.Size = New-Object System.Drawing.Size(280,40)
$objLabel.Text = "Select a script from the dropdown and enter any information required:"
$objForm.Controls.Add($objLabel)

#$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()
