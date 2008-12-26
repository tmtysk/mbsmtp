require 'net/smtp'
require 'rubygems'
require 'tmail'

class MbSmtp < Net::SMTP
  # 1セッションあたりに送信するメッセージ数
  MAX_MESSAGES_PER_SESSION = 20
  # ブロックを受けたときのスリープ時間(秒)
  SLEEP_TIME_ON_BUSY = 30
  # ブロックを受けた際の再試行回数上限
  RETRY_COUNT_MAX = 3
  # docomo メールサーバ
  DOCOMO_MX_SERVER = 'mfsmax.docomo.ne.jp'
  # au メールサーバ
  AU_MX_SERVER = 'lsean.ezweb.ne.jp'
  # SoftBank メールサーバ
  SOFTBANK_MX_SERVER = 'mx.softbank.ne.jp'

  # 初期化
  def initialize(address, port=nil)
    case address
    when :docomo
      address = DOCOMO_MX_SERVER
    when :au
      address = AU_MX_SERVER
    when :softbank
      address = SOFTBANK_MX_SERVER
    end
    super
    # 送信メッセージの配列
    @msgs = []
    # エラー宛先リスト
    @err_recipients = Hash.new
    # 送信要求されたメッセージの総数
    @request_msg_count = 0
    # 送信できたメッセージの総数
    @sent_msg_count = 0
    # ブロックを受けた回数
    @blocked_count = 0
  end

  # オリジナルの start をオーバーライド
  # ブロック内のメッセージをそのまま送信せず、バッファリングした上で
  # 所定のメッセージ数に分割しながら送信する
  alias_method :start_original, :start
  def start(helo = "localhost.localdomain",
            user = nil, secret = nil, authtype = nil) # :yield: smtp
    sent_addrs = []
    # ブロックを伴う呼び出しのみ有効
    if block_given? then
      # ブロック内で指定されたメッセージを全て取り出し
      yield(self)
      @request_msg_count = @msgs.length

      until @msgs.empty?
        # セッションごとに送信する部分配列を取り出す
        msgs = @msgs.slice!(0, MAX_MESSAGES_PER_SESSION)
        begin
          do_start(helo, user, secret, authtype)
          msgs.each do |m|
            begin
              # 送信先に既にエラーとわかってるものがあれば取り除く
              m.to_addrs.delete_if do |to| @err_recipients[to] end
              next if m.to_addrs.empty?
              send_message_original(m.msgstr, m.from_addr, m.to_addrs)
              sent_addrs << m.to_addrs
              @sent_msg_count += m.to_addrs.length
            rescue Net::SMTPServerBusy => e
              # サーバービジー (docomo のセッション中キャリアブロック
              puts "blocked!(server busy)"
              @blocked_count += 1
              break if @blocked_count >= RETRY_COUNT_MAX # この時点では最後まで抜けない
              puts " waiting for #{SLEEP_TIME_ON_BUSY} seconds."
              sleep SLEEP_TIME_ON_BUSY
              getok('RSET')
              redo
            rescue Net::SMTPFatalError => e
              # 宛先不明
              err_recipient = e.message.scan(/[^\s\r\n\t'"]+@[^\s\r\n\t'"]+/).first
              @err_recipients[err_recipient] = true
              getok('RSET')
              next
            end
          end
        rescue Net::SMTPServerBusy => e
          # サーバービジー (docomo の接続時キャリアブロック
          puts "blocked!(server busy)"
          @blocked_count += 1
          break if @blocked_count >= RETRY_COUNT_MAX
          puts " waiting for #{SLEEP_TIME_ON_BUSY} seconds."
          sleep SLEEP_TIME_ON_BUSY
          redo
        rescue StandardError => e
          if e.message =~ /^Errno::ENETUNREACH/ then
            # ネットワーク異常 (キャリアブロックかも
            puts "blocked!(network unreachable)"
            @blocked_count += 1
            break if @blocked_count >= RETRY_COUNT_MAX
            puts " waiting for #{SLEEP_TIME_ON_BUSY} seconds."
            sleep SLEEP_TIME_ON_BUSY
            redo
          elsif e.message =~ /end of file reached/
            # SMTP セッション中のエラー .. 接続からただちにやりなおす
            puts "session error .. retrying in a moment."
            redo
          else
            # その他のエラー
            puts "Unknown Error: #{e.message}"
            redo
          end
        ensure
          do_finish
        end
      end
    # ブロックを伴わない呼び出しは無視する
#    else
#      do_start(helo, user, secret, authtype)
#      return self
    end

    # 送信結果の構造体を返す
    Result.new(@request_msg_count, @sent_msg_count, sent_addrs.flatten.uniq, @err_recipients.keys, @msgs)
  end

=begin
    def getok( fmt, *args )
      res = critical {
        printf(fmt + "\n", *args)
        @socket.writeline sprintf(fmt, *args)
        recv_response()
      }
      return check_response(res)
    end

    def get_response( fmt, *args )
      printf(fmt + "\n", *args) 
      @socket.writeline sprintf(fmt, *args)
      recv_response()
    end

    def recv_response
      res = ''
      while true
        line = @socket.readline
        res << line << "\n"
        break unless line[3] == ?-   # "210-PIPELINING"
      end
      p res
      res
    end
=end

  # オリジナルの send_message をオーバーライド
  # この時点では送らず、メンバ変数に格納する
  alias_method :send_message_original, :send_message
  def send_message(msgstr, from_addr, *to_addrs)
    @msgs << Message.new(msgstr, from_addr, to_addrs)
  end
  alias send_mail send_message
  alias sendmail send_message   # obsolete

  # メッセージの構造体
  Message = Struct.new(
    # メッセージ文字列
    :msgstr,
    # MAIL FROM
    :from_addr,
    # RCPT TO
    :to_addrs
  )
  
  # 送信結果の構造体
  Result = Struct.new(
    # 要求されたメッセージの総数(複数宛先のメッセージも1とカウント)
    :request_msg_count,
    # 送信されたメッセージの総数(複数宛先のメッセージも1とカウント)
    :sent_msg_count,
    # 正常に送信できた宛先アドレスの配列
    :sent_addrs,
    # Unknown user で送達できないと判明した宛先アドレスの配列
    :err_addrs,
    # 要求されたが、リトライ回数制限に達したため送信試行しなかったメッセージの配列
    :not_tried_msgs
  )

end
