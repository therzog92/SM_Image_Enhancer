# 🎮 StepMania Image Enhancer

A powerful tool designed to enhance and optimize image files used in StepMania charts. This tool automatically processes backgrounds, banners, and jacket images while preserving your chart file structure.

## ✨ Features

### 🔍 Intelligent File Detection
- Automatically scans and analyzes StepMania (.SM/.SSC) chart files
- Identifies and categorizes image files based on chart references:
  - Background images
  - Banner images 
  - Jacket images
- Smart detection of unmarked images based on filename patterns

### 🖼️ Advanced Image Processing
- **AI Upscaling** using Real-ESRGAN with five specialized models:
  1. **realesrgan-x4plus-anime**
     - Optimized for anime-style artwork and illustrations
     - 4x upscaling factor
  2. **realesr-animevideov3-x2**
     - Enhanced anime processing with 2x upscaling
     - Better for preserving fine details
  3. **realesr-animevideov3-x3**
     - Enhanced anime processing with 3x upscaling
     - Balanced between detail and enlargement
  4. **realesr-animevideov3-x4**
     - Enhanced anime processing with 4x upscaling
     - Maximum enlargement for anime content
  5. **realesrgan-x4plus**
     - General-purpose upscaling model
     - Better for photographic or realistic images
     - 4x upscaling factor

- **Resolution Control** with preset targets:
  - 720p (1280px width)
  - 1080p (1920px width) 
  - 1440p (2560px width)
  - 2160p (4000px width)

- **Intelligent Resizing** based on image type:
  - Backgrounds: Full target width
  - Banners: 1/3 target width
  - Jackets: 1/5 target width

- **Image Optimization**:
  - PNG compression using PNGQuant
  - JPEG optimization using JPEGOptim
  - General resizing with ImageMagick

### 💾 Flexible Output Options
- Overwrite existing files
- Create new directory structure
    - Directory with same folder structure will be created with this option at the specified destination.
    - This is recommended-- it allows you to view the output before commiting.  If satisfied-- drag the directory
      onto the source directory and agree to overwrite files!
- Process tracking with progress bars and time estimates
- Detailed processing summaries and error reporting

## 🚀 Usage

1. Run the script and select your StepMania songs directory
   - or whichever directory you'd like to scan, or a specific song folder if you just want one song!
   - The the powershell file must be in the same directory as the "BackendCode" directory as they're relative to one another
2. Choose processing mode:
   - Upscale and Compress
   - Upscale Only
   - Compress Only
3. Select desired resolution and upscaling model (if applicable)
4. Choose output method
5. Monitor progress and review results

## ⚙️ Requirements

- Windows PowerShell
- Backend tools (included, no install needed):
  - Real-ESRGAN
  - PNGQuant
  - JPEGOptim
  - ImageMagick

## 📋 Features Overview

- **Scan & Analyze**
  - Recursive directory scanning
  - Automatic file categorization
  - Smart file type detection

- **Process & Enhance**
  - RealESRGAN-powered upscaling
  - Multiple resolution options
  - Intelligent size optimization

- **Monitor & Control**
  - Real-time progress tracking
  - Time remaining estimates
  - Detailed success/error reporting


## 🏆 Credits

This tool integrates several powerful open-source projects:

- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) - Neural network upscaling
- [PNGQuant](https://pngquant.org/) - PNG compression
- [JPEGOptim](https://github.com/tjko/jpegoptim) - JPEG optimization
- [ImageMagick](https://imagemagick.org/) - Image processing

## 👨‍💻 Author

Created by Tommy Herzog

## 🤝 Contributing

Contributions and features are all welcome!

## 💬 Support

No ongoing support-- just wanted to make something to upscale images from packs in the future since I play on a 4k tv.  
Feel free to take the code and do what you please with it!

---

*Note: Processing speed depends on your system's CPU and GPU capabilities.*
