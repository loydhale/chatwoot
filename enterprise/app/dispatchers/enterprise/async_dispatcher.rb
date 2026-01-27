module Enterprise::AsyncDispatcher
  def listeners
    super + [
      AtlasListener.instance
    ]
  end
end
