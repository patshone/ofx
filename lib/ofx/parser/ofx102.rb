require "bigdecimal"

module OFX
  module Parser
    class OFX102
      VERSION = "1.0.2"
      
      ACCOUNT_TYPES = {
        "CHECKING" => :checking
      }
      
      TRANSACTION_TYPES = {
        "CREDIT" => :credit,
        "DEBIT" => :debit,
        "OTHER" => :other,
        "POS" => :pos,
        "ATM" => :atm
      }
      
      attr_reader :headers
      attr_reader :body
      attr_reader :html
      
      def initialize(options = {})
        @headers = options[:headers]
        @body = options[:body]
        @html = Nokogiri::HTML.parse(body)
      end
      
      def accounts
        @accounts = build_accounts
      end
      
      private
        def build_accounts
          html.search("bankmsgsrsv1 > stmttrnrs").collect do |account|
            build_account(account)
          end
        end
           
        def build_account(account)
          OFX::Account.new({
            :bank_id      => account.search("bankacctfrom > bankid").inner_text,
            :id           => account.search("bankacctfrom > acctid").inner_text,
            :type         => ACCOUNT_TYPES[account.search("bankacctfrom > accttype").inner_text],
            :transactions => build_transactions(account),
            :balance      => build_balance(account),
            :currency     => account.search("stmtrs > curdef").inner_text
          })
        end
        
        def build_transactions(account)
          account.search("banktranlist > stmttrn").collect do |element|
            build_transaction(element)
          end
        end
        
        def build_transaction(element)
          amount = BigDecimal.new(element.search("trnamt").inner_text)
          
          OFX::Transaction.new({
            :amount => amount,
            :amount_in_pennies => (amount * 100).to_i,
            :fit_id => element.search("fitid").inner_text,
            :name => element.search("name").inner_text,
            :memo => element.search("memo").inner_text,
            :payee => element.search("payee").inner_text,
            :check_number => element.search("checknum").inner_text,
            :ref_number => element.search("refnum").inner_text,
            :posted_at => build_date(element.search("dtposted").inner_text),
            :type => TRANSACTION_TYPES[element.search("trntype").inner_text]
          })
        end
        
        def build_date(date)
          _, year, month, day, hour, minutes, seconds = *date.match(/(\d{4})(\d{2})(\d{2})(?:(\d{2})(\d{2})(\d{2}))?/)
          
          date = "#{year}-#{month}-#{day} "
          date << "#{hour}:#{minutes}:#{seconds}" if hour && minutes && seconds
          
          Time.parse(date)
        end
        
        def build_balance(account)
          amount = account.search("ledgerbal > balamt").inner_text.to_f
          
          OFX::Balance.new({
            :amount => amount,
            :amount_in_pennies => (amount * 100).to_i,
            :posted_at => build_date(account.search("ledgerbal > dtasof").inner_text)
          })
        end
    end
  end
end
