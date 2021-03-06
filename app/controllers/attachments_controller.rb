class AttachmentsController < ApplicationController
  before_action :authenticate_user! #, only: [:controller]

  skip_before_action :verify_authenticity_token, only: [:controller]



  def manage
    case request.method
      when 'POST'
        a = Attachment.find params[:id]
        if a.user_id == current_user.id
          a.destroy
        else
          flash[:alert] = t('labels.require_role')
        end
      else
    end
    @attachments = Attachment.select(:id,:content_type, :title, :avatar, :created_at).order(id: :desc).where(user_id: current_user.id).page params[:page]
    render 'manage', layout: 'dashboard'
  end

  def controller
    cfg = JSON.parse File.read("#{Rails.root}/config/ueditor.json")

    case Rack::Utils.parse_query(URI(request.url).query)['action']
      when 'config'
        ret = cfg
      when 'uploadimage'
        ret = _store current_user.id, params.fetch(cfg.fetch('imageFieldName').to_sym)
      when 'uploadscrawl'
        file = Tempfile.new %w(scrawl .png), encoding: 'ascii-8bit'
        begin
          file.write Base64.strict_decode64(params.fetch(cfg.fetch('scrawlFieldName').to_sym))
          file.flush
          ret = _store current_user.id, file, 'scrawl.png', 'image/png'
        ensure
          file.close
          file.unlink
        end
      when 'uploadvideo'
        ret = _store current_user.id, params.fetch(cfg.fetch('videoFieldName').to_sym)
      when 'uploadfile'
        ret = _store current_user.id, params.fetch(cfg.fetch('fileFieldName').to_sym)
      when 'listimage'
        ret = _list current_user.id, cfg.fetch('imageManagerAllowFiles')
      when 'listfile'
        ret = _list current_user.id, cfg.fetch('fileManagerAllowFiles')
      when 'catchimage'
        ret= _remote_image current_user.id, params.fetch(cfg.fetch('catcherFieldName').to_sym)
      else
        ret = {state: t('labels.ueditor.error.address')}
    end

    cb = params[:callback]
    if cb
      if cb =~ /^[\w_]+$/
        render plain: "<script>#{cb}(#{ret})</script"
      else
        render json: {state: t('labels.ueditor.error.callback')}
      end
    else
      render json: ret
    end

  end

  private

  def _remote_image(user_id, urls)
    files = urls.map do |url|
      ret = {}
      res = Net::HTTP.get_response URI(url)
      ext = File.extname(url)
      file = Tempfile.new ['remote', ext], encoding: 'ascii-8bit'
      begin
        if res.is_a?(Net::HTTPSuccess)
          if res.content_type.include?('image')
            file.write res.body
            file.flush
            ret = _store user_id, file, url, _ext2type(ext)
          else
            ret['state'] = '不是图片'
          end
        else
          ret['state'] = 'HTTP错误'
        end
      ensure
        file.close
        file.unlink
      end
      ret
    end
    {state: (files.empty? ? 'ERROR' : 'SUCCESS'), list: files}
  end

  def _list(user_id, types)
    files = Attachment.where(user_id: user_id).order(id: :desc).select { |a| types.include? File.extname(a.avatar.to_s) }.map { |a| a.avatar.url }
    {
        state: 'SUCCESS',
        list: files,
        start: 0,
        total: files.size
    }
  end


  def _store(user_id, file, name=nil, type=nil)
    name ||= file.original_filename
    type ||= file.content_type

    attach = Attachment.new user_id: user_id
    attach.content_type = type
    attach.title = name
    attach.ext = file_ext name
    attach.avatar = file
    attach.save!
    {
        state: 'SUCCESS',
        url: attach.avatar.url,
        title: attach.avatar.identifier
    }
  end



  def _ext2type(ext)
    Mime::Type.lookup_by_extension(ext) || 'application/octet-stream'
  end


end
