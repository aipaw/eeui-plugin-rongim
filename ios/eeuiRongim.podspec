

Pod::Spec.new do |s|



  s.name         = "eeuiRongim"
  s.version      = "1.0.0"
  s.summary      = "eeui plugin."
  s.description  = <<-DESC
                    eeui plugin.
                   DESC

  s.homepage     = "https://eeui.app"
  s.license      = "MIT"
  s.author             = { "kuaifan" => "aipaw@live.cn" }
  s.source =  { :path => '.' }
  s.source_files  = "eeuiRongim", "**/**/*.{h,m,mm,c}"
  s.exclude_files = "Source/Exclude"
  s.resources = 'eeuiRongim/Source/*.*'
  s.vendored_libraries = 'eeuiRongim/Utility/Rong_Cloud_iOS_IMLib_SDK_v2_10_2_Dev/IMLib/*.a'
  s.vendored_frameworks = 'eeuiRongim/Utility/Rong_Cloud_iOS_IMLib_SDK_v2_10_2_Dev/IMLib/*.framework'
  s.platform     = :ios, "8.0"
  s.requires_arc = true

  s.dependency 'WeexSDK'
  s.dependency 'eeui'
  s.dependency 'WeexPluginLoader', '~> 0.0.1.9.1'

end
