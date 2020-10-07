module VimeoMe2
  module UserMethods
    module Upload

      # Upload a video object to the authenticated account
      #
      # @param [File] video A File that contains a valid video format
      def upload_video video, name: nil, description: nil
        @video = video
        @ticket = create_video(name: name, description: description)
        start_upload
        @ticket
      end

      # Upload a video to the authenticated account
      #   The video is pulled automatically
      #
      # @param [String] name video name
      # @param [String] link a link to a video on the Internet that is accessible to Vimeo’s upload server
      def pull_upload name, link, options = {}
        body = {
          upload: { approach: 'pull', link: link},
          name: name.present? ? name : @video.original_filename
        }.merge!(options)

        post '/videos', body: body, code: 201
      end

      private
        def get_file_name
          return @video.path if @video.is_a? File
          return @video.original_filename
        end

        # 3.4 Update
        def create_video(name: nil, description: nil)
          body = {
            name: name || get_file_name,
            upload: {
              approach: 'tus',
              size: @video.size.to_s
            }
          }
          body[:description] = description if description
          post '/videos', body: body, code: 200
        end

        # start the upload
        def start_upload
          headers = {
            'Content-Type' => 'application/offset+octet-stream',
            'Tus-Resumable' => '1.0.0'
          }

          video_size = @video.size
          video_chunk_size = if video_size < mb_to_b(1024)
                               mb_to_b(128)
                             else
                               mb_to_b(256)
                             end
          
          upload_link = @ticket['upload']['upload_link']
          upload_offset = 0

          begin
            headers['Upload-Offset'] = upload_offset.to_s
            @video.seek upload_offset
            video_chunk = @video.read video_chunk_size
            patch upload_link, body: video_chunk, headers: headers, code: 204
            upload_offset = @client.last_request.headers['upload-offset'].to_i
          end while upload_offset < video_size
        end

        def mb_to_b(mb)
          mb * 1024 * 2014
        end
    end
  end
end
