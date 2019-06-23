

Pod::Spec.new do |s|



  s.name         = "rongim"
  s.version      = "0.0.1"
  s.summary      = "eeui plugin."
  s.description  = <<-DESC
                    eeui plugin.
                   DESC

  s.homepage     = "https://eeui.app"
  s.license      = "MIT"
  s.author             = { "veryitman" => "aipaw@live.cn" }
  s.source =  { :path => '.' }
  s.source_files  = "rongim", "**/**/*.{h,m,mm,c}"
  s.exclude_files = "Source/Exclude"
  s.resources = 'rongim/Source/*.*'
  s.vendored_libraries = 'rongim/Utility/Rong_Cloud_iOS_IMLib_SDK_v2_9_1_Stable/IMLib/*.a'
  s.vendored_frameworks = 'rongim/Utility/Rong_Cloud_iOS_IMLib_SDK_v2_9_1_Stable/IMLib/*.framework'
  s.platform     = :ios, "8.0"
  s.requires_arc = true

  s.dependency 'WeexSDK'
  s.dependency 'eeui'
  s.dependency 'WeexPluginLoader', '~> 0.0.1.9.1'

end
