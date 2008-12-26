require File.dirname(__FILE__) + '/../spec_helper'

# テスト時は以下の定数を適宜設定すること
# テストメール送信元
FROM = "test@example.com"
# docomo の受信可能なメールアドレス
DOCOMO_RECEIVABLE = "@docomo.ne.jp"
# docomo の受信不可能(存在しない)なメールアドレス
DOCOMO_UNRECEIVABLE = "@docomo.ne.jp"
# au の受信可能なメールアドレス
AU_RECEIVABLE = "@ezweb.ne.jp"
# au の受信不可能(存在しない)なメールアドレス
AU_UNRECEIVABLE = "@ezweb.ne.jp"
# SoftBank の受信可能なメールアドレス
SOFTBANK_RECEIVABLE = "@softbank.ne.jp"
# SoftBank の受信不可能(存在しない)なメールアドレス
SOFTBANK_UNRECEIVABLE = "@softbank.ne.jp"

describe MbSmtp, "は" do
  before do
    @from = FROM
    @subject = "test"
    @body = "this is test"
    # テストメール
    @mail = TMail::Mail.new
    @mail.from = @from
    @mail.subject = @subject
    @mail.body = @body
  end
  it "docomo 宛のメールを正しく送信できる" do
    @mail.to = DOCOMO_RECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:docomo) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 1
    @result.sent_addrs.length.should == 1
    @result.err_addrs.length.should == 0
    @result.not_tried_msgs.length.should == 0
  end
  it "docomo 宛の宛先不明メールを正しく認識できる" do
    @mail.to = DOCOMO_UNRECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:docomo) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 0
    @result.sent_addrs.length.should == 0
    @result.err_addrs.length.should == 1
    @result.not_tried_msgs.length.should == 0
  end
  it "au 宛のメールを正しく送信できる" do
    @mail.to = AU_RECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:au) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 1
    @result.sent_addrs.length.should == 1
    @result.err_addrs.length.should == 0
    @result.not_tried_msgs.length.should == 0
  end
  it "au 宛の宛先不明メールを正しく認識できる" do
    @mail.to = AU_UNRECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:au) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 0
    @result.sent_addrs.length.should == 0
    @result.err_addrs.length.should == 1
    @result.not_tried_msgs.length.should == 0
  end
  it "SoftBank 宛のメールを正しく送信できる" do
    @mail.to = SOFTBANK_RECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:softbank) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 1
    @result.sent_addrs.length.should == 1
    @result.err_addrs.length.should == 0
    @result.not_tried_msgs.length.should == 0
  end
  it "SoftBank 宛の宛先不明メールを正しく認識できる" do
    @mail.to = SOFTBANK_UNRECEIVABLE
    @result = MbSmtp::Result.new
    lambda {
      @result = MbSmtp.start(:softbank) do |smtp|
        smtp.send_mail @mail.encoded, @mail['from'].to_s, @mail['to'].to_s
      end
    }.should_not raise_error
    @result.request_msg_count.should == 1
    @result.sent_msg_count.should == 0
    @result.sent_addrs.length.should == 0
    @result.err_addrs.length.should == 1
    @result.not_tried_msgs.length.should == 0
  end
end
