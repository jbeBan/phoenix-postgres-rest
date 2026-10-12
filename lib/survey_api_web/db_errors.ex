# Pool exhausted or database unreachable: a retryable 503, not a 500.
defimpl Plug.Exception, for: DBConnection.ConnectionError do
  def status(_exception), do: 503
  def actions(_exception), do: []
end
