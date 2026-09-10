class Config
  def self.load(raw)
    YAML.safe_load(raw, permitted_classes: [Symbol])
  end
end
