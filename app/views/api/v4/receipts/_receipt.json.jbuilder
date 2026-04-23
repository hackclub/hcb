object_shape(json, receipt) do
  json.url receipt.url
  json.preview_url receipt.preview(only_path: false)
  json.filename receipt.file.blob.filename
  json.uploader do
    if receipt.user.present?
      json.partial! "api/v4/users/user", user: receipt.user
    else
      json.nil!
    end
  end
end
