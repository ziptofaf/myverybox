class SystemSettings
  def initialize
  end
  
  def space_available
    output = `df -h`
    output.split("\n")
  rescue 
    []
  end
end