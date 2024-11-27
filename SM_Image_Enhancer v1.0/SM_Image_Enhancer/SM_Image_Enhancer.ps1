# Clear the console at start
Clear-Host

# Display title splash screen
$titleSplash = @"
===========================================
   StepMania Image Enhancer v1.0
===========================================

A comprehensive tool for StepMania image enhancing:

- Scans and analyzes Stepmania (.SM/.SSC) chart files for image file references
- Categorizes image files by type based on Stepmania chart file references:
  - Backgrounds
  - Banners 
  - Jackets
- Image Processing Features:
  - Computer-based AI Upscaling with Real-ESRGAN:
    * Multiple upscaling models available
    * Models optimized for anime/artwork
  - Resizes upscaled images with ImageMagick to selected display resolution 
    * 720p (1280x), 1080p (1920x), 1440p (2560x), 2160p (4000x)
  - Compresses files using PNGQuant/JPEGOPTIM
- Shows progress and time estimates

* Upscaling and compression speed will vary based on available 
system resources, especially CPU and GPU performance.

Created by Tommy Herzog
===========================================

"@

Write-Host $titleSplash -ForegroundColor Cyan
Write-Host "Press Enter to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Function to remove quotes from a string
function Remove-Quotes {
    param (
        [string]$inputString
    )
    return $inputString.Trim('"').Trim("'")
}

# Function to escape special characters in file names
function Escape-SpecialCharacters {
    param (
        [string]$fileName
    )
    return [regex]::Escape($fileName)
}

# Function to update progress
function Write-Progress-Bar {
    param (
        [int]$Current,
        [int]$Total,
        [string]$CurrentFile,
        [System.DateTime]$StartTime
    )
    $percentComplete = [math]::Round(($Current / $Total) * 100)
    $elapsedTime = ([System.DateTime]::Now - $StartTime)
    $estimatedTotalTime = $elapsedTime.TotalSeconds / ($Current / $Total)
    $remainingTime = $estimatedTotalTime - $elapsedTime.TotalSeconds
    $eta = [System.DateTime]::Now.AddSeconds($remainingTime)
    
    Write-Progress -Activity "Processing Files - Estimated Time Remaining: $([math]::Floor($remainingTime/3600)) Hours $([math]::Floor(($remainingTime%3600)/60)) Minutes" -Status "Processing: $CurrentFile" -PercentComplete $percentComplete
}

# Function to safely remove temp file if it exists
function Remove-TempFile {
    param (
        [string]$tempFile
    )
    if (Test-Path $tempFile) {
        Remove-Item $tempFile
    }
}

# Function to get file size in MB
function Get-FileSizeMB {
    param (
        [string]$filePath
    )
    return [math]::Round((Get-Item $filePath).Length / 1MB, 2)
}

# Set paths for tools
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $scriptPath "BackendCode"
$realesrganPath = Join-Path $backendPath "realesrgan\realesrgan-ncnn-vulkan.exe"
$pngquantPath = Join-Path $backendPath "pngquant\pngquant.exe"
$jpegoptimPath = Join-Path $backendPath "jpegoptim\jpegoptim.exe"
$magickPath = Join-Path $backendPath "ImageMagick\magick.exe"

# Create and configure folder browser dialog
Add-Type -AssemblyName System.Windows.Forms
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Select the directory to scan"
$folderBrowser.RootFolder = [System.Environment+SpecialFolder]::Desktop
$folderBrowser.ShowNewFolderButton = $true

# Create a form to host the folder browser
$form = New-Object System.Windows.Forms.Form
$form.Text = "Select Directory"
$form.Width = 800
$form.Height = 600
$form.StartPosition = "CenterScreen"

Write-Host "`nPlease select a directory to scan..."

# Show folder browser dialog
if ($folderBrowser.ShowDialog($form) -eq 'OK') {
    $searchDir = $folderBrowser.SelectedPath
    
    Write-Host "`nScanning directory: $searchDir"

    # Start timing the scan
    $scanTimer = [System.Diagnostics.Stopwatch]::StartNew()

    # Get all simfiles and count unique folders
    $simfiles = Get-ChildItem -LiteralPath $searchDir -File -Recurse | Where-Object { $_.Extension -match "\.sm|\.ssc" }
    $totalSimfiles = $simfiles.Count
    $totalFolders = ($simfiles | Select-Object DirectoryName -Unique).Count

    Write-Host "Found $totalSimfiles Stepmania Simfiles in $totalFolders folders`n"

    # Initialize file mapping and tracking variables
    $fileMapping = @{}
    $uniqueFolders = @{}
    $currentSimfile = 0

    # Process simfiles
    foreach ($file in $simfiles) {
        $currentSimfile++
        Write-Progress-Bar -Current $currentSimfile -Total $totalSimfiles -CurrentFile $file.Name -StartTime ([System.DateTime]::Now)
        
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $currentDir = $file.DirectoryName
        $uniqueFolders[$currentDir] = $true

        # Get all image files in current directory
        $allImageFiles = Get-ChildItem -LiteralPath $currentDir -File | Where-Object { $_.Extension -match "\.(png|jpe?g)$" }

        # Process BACKGROUND
        if ($content -match '#BACKGROUND:([^;]+);') {
            $bgFile = $matches[1].Trim()
            $escapedBgFile = Escape-SpecialCharacters $bgFile
            $matchingFiles = $allImageFiles | Where-Object { $_.Name -match $escapedBgFile }
            foreach ($match in $matchingFiles) {
                $fileMapping[$match.FullName] = "background"
            }
        }

        # Process BANNER
        if ($content -match '#BANNER:([^;]+);') {
            $bannerFile = $matches[1].Trim()
            $escapedBannerFile = Escape-SpecialCharacters $bannerFile
            $matchingFiles = $allImageFiles | Where-Object { $_.Name -match $escapedBannerFile }
            foreach ($match in $matchingFiles) {
                $fileMapping[$match.FullName] = "banner"
            }
        }

        # Process JACKET
        if ($content -match '#JACKET:([^;]+);') {
            $jacketFile = $matches[1].Trim()
            $escapedJacketFile = Escape-SpecialCharacters $jacketFile
            $matchingFiles = $allImageFiles | Where-Object { $_.Name -match $escapedJacketFile }
            foreach ($match in $matchingFiles) {
                $fileMapping[$match.FullName] = "jacket"
            }
        }
    }

    # Clear the progress bar
    Write-Progress -Activity "Scanning Simfiles" -Completed

    # Process undesignated files
    $undesignatedFiles = @()

    foreach ($folder in $uniqueFolders.Keys) {
        $imageFiles = Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Extension -match "\.(png|jpe?g)$" }
        foreach ($image in $imageFiles) {
            if (-not $fileMapping.ContainsKey($image.FullName)) {
                $fileName = $image.Name.ToLower()
                if ($fileName -match "bg|background") {
                    $fileMapping[$image.FullName] = "background"
                }
                elseif ($fileName -match "bn|banner") {
                    $fileMapping[$image.FullName] = "banner"
                }
                elseif ($fileName -match "jacket") {
                    $fileMapping[$image.FullName] = "jacket"
                }
                else {
                    $undesignatedFiles += $image.FullName
                }
            }
        }
    }

    # Stop timing
    $scanTimer.Stop()
    $scanTime = $scanTimer.Elapsed

    # Group files by type and sort
    $backgrounds = $fileMapping.GetEnumerator() | Where-Object { $_.Value -eq "background" } | Sort-Object Key
    $banners = $fileMapping.GetEnumerator() | Where-Object { $_.Value -eq "banner" } | Sort-Object Key
    $jackets = $fileMapping.GetEnumerator() | Where-Object { $_.Value -eq "jacket" } | Sort-Object Key
    $undesignated = $undesignatedFiles | Sort-Object

    # Display summary
    Write-Host "`nScan Complete!"
    Write-Host "=============="
    Write-Host "Backgrounds Found: $($backgrounds.Count)"
    Write-Host "Banners Found: $($banners.Count)" 
    Write-Host "Jackets Found: $($jackets.Count)"
    Write-Host "Undesignated Images (Will not be processed): $($undesignated.Count)"
    Write-Host "Total Scan Time: $($scanTime.Minutes)m $($scanTime.Seconds)s $($scanTime.Milliseconds)ms"

    # Ask user for processing options
    $options = @("Upscale and Compress", "Upscale Only", "Compress Only")
    Write-Host "`nSelect processing option:"
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "$($i+1). $($options[$i])"
    }
    $choice = Read-Host "Enter your choice (1-3)"

    $resolutions = [ordered]@{
        "720p" = 1280
        "1080p" = 1920
        "1440p" = 2560
        "2160p" = 4000
    }
    
    $models = @(
        "realesrgan-x4plus-anime",
        "realesr-animevideov3-x2",
        "realesr-animevideov3-x3", 
        "realesr-animevideov3-x4",
        "realesrgan-x4plus"
    )
    
    if ($choice -in "1","2") {
        # Get resolution choice
        Write-Host "`nSelect target resolution:"
        $resOptions = [array]($resolutions.Keys)
        for ($i = 0; $i -lt $resOptions.Count; $i++) {
            Write-Host "$($i+1). $($resOptions[$i])"
        }
        $resChoice = Read-Host "Enter your choice (1-4)"
        $selectedRes = $resOptions[[int]$resChoice - 1]
        $targetWidth = $resolutions[$selectedRes]

        # Get model choice
        Write-Host "`nSelect upscaling model:"
        for ($i = 0; $i -lt $models.Count; $i++) {
            Write-Host "$($i+1). $($models[$i])"
        }
        $modelChoice = Read-Host "Enter your choice (1-5)"
        $selectedModel = $models[$modelChoice - 1]

        # Get output preference
        Write-Host "`nSelect output preference:"
        Write-Host "1. Overwrite existing files"
        Write-Host "2. Create new directory structure"
        $outputChoice = Read-Host "Enter your choice (1-2)"

        $outputDir = $searchDir
        if ($outputChoice -eq "2") {
            # Create new folder browser for output directory
            $outputFolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $outputFolderBrowser.Description = "Select output directory"
            $outputFolderBrowser.RootFolder = [System.Environment+SpecialFolder]::Desktop
            $outputFolderBrowser.SelectedPath = $scriptPath
            $outputFolderBrowser.ShowNewFolderButton = $true

            Write-Host "`nPlease select where to save the processed files..."
            if ($outputFolderBrowser.ShowDialog() -eq 'OK') {
                $outputDir = $outputFolderBrowser.SelectedPath
                
                # Get the name of the source folder
                $sourceFolderName = Split-Path $searchDir -Leaf
                
                # Create the source folder structure in output directory
                $outputDir = Join-Path $outputDir $sourceFolderName
                
                # Create the directory if it doesn't exist
                if (-not (Test-Path $outputDir)) {
                    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
                }
            } else {
                Write-Host "No output directory selected. Using script directory."
                $outputDir = $scriptPath
            }
        }

        # Calculate target widths for each type
        $bgWidth = $targetWidth
        $bannerWidth = [int]($targetWidth/3)
        $jacketWidth = [int]($targetWidth/5)

        # Display confirmation message
        Write-Host "`nProgram set to perform the following actions:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        Write-Host "Upscale $($backgrounds.Count) backgrounds, $($banners.Count) banners, $($jackets.Count) jackets using RealESRGAN model '$selectedModel'"
        Write-Host "Resize the upscaled images using ImageMagick to:"
        Write-Host "- Backgrounds: $bgWidth pixels wide"
        Write-Host "- Banners: $bannerWidth pixels wide"
        Write-Host "- Jackets: $jacketWidth pixels wide"
        
        if ($outputChoice -eq "1") {
            Write-Host "Source files will be overwritten"
        } else {
            Write-Host "New folder structure will be created at: $outputDir"
            Write-Host "You can drag it to the source to overwrite if you are satisfied with the results"
        }

        if ($choice -eq "1") {
            Write-Host "Files will be compressed using PNGQUANT/JPEGOPTIM after processing"
        }

        Write-Host "`nSelect an option:" -ForegroundColor Cyan
        Write-Host "1. Proceed with processing"
        Write-Host "2. Return to main menu"
        Write-Host "3. Exit program"
        
        $confirmChoice = Read-Host "Enter your choice (1-3)"
        
        switch ($confirmChoice) {
            "1" {
                # Initialize counters for summary
                $totalFiles = ($backgrounds.Count + $banners.Count + $jackets.Count)
                $totalProcessed = 0
                $totalErrors = 0
                $errorList = @()
                $processingStartTime = [System.DateTime]::Now

                # Process files
                foreach ($type in @($backgrounds, $banners, $jackets)) {
                    foreach ($item in $type) {
                        $totalProcessed++
                        $file = $item.Key
                        $designation = $item.Value
                        
                        # Get relative path for display
                        $relativePath = $file.Substring($searchDir.Length).TrimStart('\')
                        
                        Write-Progress-Bar -Current $totalProcessed -Total $totalFiles -CurrentFile $relativePath -StartTime $processingStartTime
                        Write-Host "`nProcessing File ${totalProcessed} of ${totalFiles}"

                        # Calculate target width based on designation
                        $finalWidth = switch ($designation) {
                            "background" { $bgWidth }
                            "banner" { $bannerWidth }
                            "jacket" { $jacketWidth }
                        }

                        if ($outputChoice -eq "2") {
                            $newPath = Join-Path $outputDir $relativePath
                            $newDir = Split-Path $newPath -Parent
                            if (!(Test-Path $newDir)) {
                                New-Item -ItemType Directory -Path $newDir -Force | Out-Null
                            }
                            $outputFile = $newPath
                        } else {
                            $outputFile = $file
                        }

                        # Get file extension from original file
                        $extension = [System.IO.Path]::GetExtension($file)
                        $tempFile = [System.IO.Path]::ChangeExtension("$outputFile.tmp", $extension)
                        
                        $originalSize = Get-FileSizeMB -filePath $file

                        try {
                            # Upscale
                            & $realesrganPath -i $file -o $tempFile -n $selectedModel *>&1 | Out-Null
                            Write-Host "---Upscaling Complete"
                            
                            if (Test-Path $tempFile) {
                                # Resize
                                & $magickPath $tempFile -resize "${finalWidth}x>" $outputFile *>&1 | Out-Null
                                Write-Host "---Resizing Complete"
                                Remove-TempFile -tempFile $tempFile

                                # Compress if needed
                                if ($choice -eq "1") {
                                    if ($outputFile -match "\.png$") {
                                        & $pngquantPath --force --ext .png $outputFile *>&1 | Out-Null
                                    } else {
                                        & $jpegoptimPath --force --strip-all $outputFile *>&1 | Out-Null
                                    }
                                    $newSize = Get-FileSizeMB -filePath $outputFile
                                    $reduction = [math]::Round((1 - ($newSize / $originalSize)) * 100)
                                    Write-Host "---Compression Complete ($reduction% reduction)"
                                }
                            }
                        }
                        catch {
                            $totalErrors++
                            $errorList += "Error processing ${relativePath}: $($_.Exception.Message)"
                            Write-Host "Error processing file: $file" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red
                        }
                        finally {
                            Remove-TempFile -tempFile $tempFile
                        }
                    }
                }

                $processingEndTime = [System.DateTime]::Now
                $processingDuration = $processingEndTime - $processingStartTime

                # Display summary
                Write-Host "`nProcessing Summary" -ForegroundColor Cyan
                Write-Host "=================" -ForegroundColor Cyan
                Write-Host "Total files processed: $totalProcessed"
                Write-Host "Successful: $($totalProcessed - $totalErrors)"
                Write-Host "Failed: $totalErrors"
                Write-Host "Total Processing Time: $($processingDuration.Hours)h $($processingDuration.Minutes)m $($processingDuration.Seconds)s"

                if ($totalErrors -gt 0) {
                    Write-Host "`nErrors encountered:" -ForegroundColor Red
                    foreach ($error in $errorList) {
                        Write-Host $error -ForegroundColor Red
                    }
                }
            }
            "2" {
                Write-Host "Returning to main menu..."
                return
            }
            "3" {
                Write-Host "Exiting program..."
                exit
            }
        }

    } elseif ($choice -eq "3") {
        # Initialize counters for summary
        $totalFiles = ($backgrounds.Count + $banners.Count + $jackets.Count)
        $totalProcessed = 0
        $totalErrors = 0
        $errorList = @()
        $processingStartTime = [System.DateTime]::Now

        # Display compression confirmation
        Write-Host "`nProgram set to perform the following actions:" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        Write-Host "Compress $($backgrounds.Count) backgrounds, $($banners.Count) banners, $($jackets.Count) jackets"
        Write-Host "PNG files will be compressed using PNGQUANT"
        Write-Host "JPEG files will be compressed using JPEGOPTIM"
        
        Write-Host "`nSelect an option:" -ForegroundColor Cyan
        Write-Host "1. Proceed with processing"
        Write-Host "2. Return to main menu"
        Write-Host "3. Exit program"
        
        $confirmChoice = Read-Host "Enter your choice (1-3)"
        
        switch ($confirmChoice) {
            "1" {
                # Compress only
                foreach ($type in @($backgrounds, $banners, $jackets)) {
                    foreach ($item in $type) {
                        $totalProcessed++
                        $file = $item.Key
                        $relativePath = $file.Substring($searchDir.Length).TrimStart('\')
                        $originalSize = Get-FileSizeMB -filePath $file

                        Write-Progress-Bar -Current $totalProcessed -Total $totalFiles -CurrentFile $relativePath -StartTime $processingStartTime
                        Write-Host "`nProcessing File ${totalProcessed} of ${totalFiles}"

                        try {
                            if ($file -match "\.png$") {
                                & $pngquantPath --force --ext .png $file *>&1 | Out-Null
                            } else {
                                & $jpegoptimPath --force --strip-all $file *>&1 | Out-Null
                            }
                            $newSize = Get-FileSizeMB -filePath $file
                            $reduction = [math]::Round((1 - ($newSize / $originalSize)) * 100)
                            Write-Host "---Compression Complete ($reduction% reduction)"
                        }
                        catch {
                            $totalErrors++
                            $errorList += "Error processing ${relativePath}: $($_.Exception.Message)"
                            Write-Host "Error processing file: $file" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red
                        }
                    }
                }

                $processingEndTime = [System.DateTime]::Now
                $processingDuration = $processingEndTime - $processingStartTime

                # Display summary
                Write-Host "`nProcessing Summary" -ForegroundColor Cyan
                Write-Host "=================" -ForegroundColor Cyan
                Write-Host "Total files processed: $totalProcessed"
                Write-Host "Successful: $($totalProcessed - $totalErrors)"
                Write-Host "Failed: $totalErrors"
                Write-Host "Total Processing Time: $($processingDuration.Hours)h $($processingDuration.Minutes)m $($processingDuration.Seconds)s"

                if ($totalErrors -gt 0) {
                    Write-Host "`nErrors encountered:" -ForegroundColor Red
                    foreach ($error in $errorList) {
                        Write-Host $error -ForegroundColor Red
                    }
                }
            }
            "2" {
                Write-Host "Returning to main menu..."
                return
            }
            "3" {
                Write-Host "Exiting program..."
                exit
            }
        }
    }

} else {
    Write-Host "`nNo directory selected"
}
Write-Host "`nSelect an option:" -ForegroundColor Yellow
Write-Host "1. Return to main menu" -ForegroundColor Yellow
Write-Host "2. Open selected directory" -ForegroundColor Yellow 
Write-Host "3. Exit" -ForegroundColor Yellow

$choice = Read-Host "Enter your choice"

switch ($choice) {
    "1" {
        Write-Host "Returning to main menu..."
        return
    }
    "2" {
        if ($outputDir -and (Test-Path $outputDir)) {
            Start-Process explorer.exe -ArgumentList $outputDir
            Write-Host "`nSelect an option:" -ForegroundColor Yellow
            Write-Host "1. Return to main menu" -ForegroundColor Yellow
            Write-Host "2. Relaunch output directory" -ForegroundColor Yellow 
            Write-Host "3. Exit" -ForegroundColor Yellow
            $choice = Read-Host "Enter your choice"
            switch ($choice) {
                "1" { return }
                "2" { Start-Process explorer.exe -ArgumentList $outputDir }
                "3" { exit }
                default {
                    Write-Host "Invalid choice. Returning to main menu..." -ForegroundColor Red
                    return
                }
            }
        } else {
            Write-Host "Selected output directory not found" -ForegroundColor Red
            return
        }
    }
    "3" {
        Write-Host "Exiting..."
        exit
    }
    default {
        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
        Write-Host "`nSelect an option:" -ForegroundColor Yellow
        Write-Host "1. Return to main menu" -ForegroundColor Yellow
        Write-Host "2. Open output directory" -ForegroundColor Yellow 
        Write-Host "3. Exit" -ForegroundColor Yellow
        $choice = Read-Host "Enter your choice"
        return
    }
}