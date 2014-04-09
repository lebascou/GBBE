require 'dropbox_sdk'

class DropboxController < ApiController

  # TODO: manage revoked access
  def initialize(storage, csrf_token = nil)
    super(storage, csrf_token)
    @flow = DropboxOAuth2Flow.new(Gatherbox::Application.config.api[storage.provider][:ID],
                                  Gatherbox::Application.config.api[storage.provider][:SECRET],
                                  Gatherbox::Application.config.api[storage.provider][:REDIRECT_URI],
                                  {:dropbox_auth_csrf_token => csrf_token},
                                  :dropbox_auth_csrf_token)
    initialize_client
  end

  def initialize_client
    if (@storage.token.nil? || @storage.token.empty?)
      @client = nil
    else
      @client = DropboxClient.new(@storage.token)
    end
  end
  def get_authorization_url
    return @flow.start("#{@storage.user.authentication_token},#{@storage.user.email}")
  end

  def authorize(code, state = nil)
    #TODO manage errors (no code / bad code...)
    access_token, user_id, url_state = @flow.finish({'code' => code, 'state' => state})
    @storage.token = access_token
    initialize_client
    return true
  end

  def get_account_infos
    account_infos = @client.account_info()
    result = Hash.new
    result[:login] = account_infos['display_name']
    result[:quota_bytes_total] = account_infos['quota_info']['quota']
    result[:quota_bytes_used] = account_infos['quota_info']['normal'] + account_infos['quota_info']['shared']
    result[:root_folder_id] = '/'
    return 200, result
  end

  def file_get(remote_id)
    api_result = @client.metadata(remote_id, 0, false)
    return 200, file_resource(api_result)
  end

  def changes(local_item)
    begin
      api_result = @client.metadata(local_item.remote_id, 25000, true, local_item.etag, nil, true)
      status_code = 200
      result = Hash.new
      result[api_result['path']] = api_result['is_deleted'] ? nil : file_resource(api_result)

      unless (api_result['contents'].nil?)
        api_result['contents'].each do |sub_file|
          if (sub_file['is_deleted'])
            result[sub_file['path']] = nil
          else
            result[sub_file['path']] = file_resource(sub_file)
            result[sub_file['path']][:parent_remote_id] = api_result['path']
          end
        end
      end

    rescue Exception => error
      result = Hash.new
      if (error.instance_of?(DropboxNotModified))
        status_code = 200
      else
        status_code = :unprocessable_entity
      end
    end
    return status_code, result
  end

  def delete(remote_id)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def patch(remote_id, resources)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def move(remote_id, old_parent_id, new_parent_id)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def copy(remote_id, parent_remote_id, copy_title)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def create_folder(title, parent_remote_id)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def upload_file(parent_remote_id, title, mime_type, file_path)
    raise "API.method.undefined #{self.class.name} #{__method__}"
  end

  def file_resource(data)
    result = Hash.new
    result[:remote_id] = data['path']
    result[:mimeType] = data['is_dir'] ? 'application/folder' : data['mime_type']
    result[:fileSize] = data['bytes']
    result[:modifiedDate] = data['modified']
    result[:title] = data['path'] == '/' ? '/' : data['path'].split('/').last
    result[:etag] = data['hash'] unless data['hash'].nil?
    return result
  end
end