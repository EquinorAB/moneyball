
# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "option_parser"
require "file_utils"
require "colorize"
require "yaml"
require "uri"

require "./core"
require "./cli/helps"
require "./cli/modules"

module ::Axentro::Interface
  alias AxeAction = NamedTuple(name: String, desc: String)

  TOKEN_DEFAULT = Core::DApps::BuildIn::UTXO::DEFAULT

  abstract class CLI
    def initialize(
      @axe_action : AxeAction,
      @parents : Array(AxeAction)
    )
      STDOUT.sync = true
      STDERR.sync = true
    end

    def puts_help(message = "showing help message.", exit_code = -1)
      if G.op.__json
        puts ({
          error:   true,
          message: message,
        }.to_json)
        exit exit_code
      end
      available_sub_actions =
        sub_actions.join("\n") { |a| " - #{light_green("%-20s" % a[:name])} | #{"%-40s" % a[:desc]}" }
      available_sub_actions = "nothing" if available_sub_actions == ""

      message_size = message.split("\n").max_by(&.size).size
      messages = message.split("\n").map { |m| white_bg(black(" %-#{message_size}s " % m)) }

      puts "\n" +
           "#{light_magenta("> " + command_line)} | #{@axe_action[:desc]}\n\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n" +
           messages.join("\n") + "\n" +
           "#{white_bg(black(" " + "-" * message_size + " "))}\n\n" +
           "available sub actions\n" +
           available_sub_actions +
           "\n\n" +
           "available options\n" +
           (option_parser.nil? ? "nothing" : option_parser.to_s) +
           "\n\n"

      exit exit_code
    end

    def encrypted?(wallet_path, wallet_password) : Bool
      Core::Wallet.from_path(wallet_path)
      false
    rescue Core::WalletException
      password_from_env = ENV["SC_WALLET_PASSWORD"]?
      password = password_from_env || wallet_password

      return false unless password

      wallet = Core::EncryptedWallet.from_path(wallet_path)
      Core::Wallet.from_json(Core::Wallet.decrypt(password, wallet))

      true
    end

    def get_wallet(wallet_path, wallet_password) : Core::Wallet
      Core::Wallet.from_path(wallet_path)
    rescue Core::WalletException
      password_from_env = ENV["SC_WALLET_PASSWORD"]?
      password = password_from_env || wallet_password

      unless password
        puts_help(HELP_WALLET_PASSWORD)
      end

      wallet = Core::EncryptedWallet.from_path(wallet_path)
      Core::Wallet.from_json(Core::Wallet.decrypt(password, wallet))
    end

    def command_line
      return @axe_action[:name] if @parents.size == 0
      @parents.join(" ", &.[:name]) + " " + @axe_action[:name]
    end

    def next_parents : Array(AxeAction)
      @parents.concat([@axe_action])
    end

    def sub_action_names : Array(String)
      sub_actions.map(&.[:name])
    end

    def run
      puts_help if ARGV.size > 0 && ARGV[0] == "help"

      action_name = if ARGV.size > 0 && !ARGV[0].starts_with?('-')
                      ARGV.shift
                    end

      if ARGV.size > 0 && ARGV[0].starts_with?('-')
        if parser = option_parser
          parser.parse
        end
      end

      run_impl(action_name)
    rescue e : Exception
      puts_error(e.message.not_nil!)
    end

    def specify_sub_action!(_sub_action : String? = nil)
      if sub_action = _sub_action
        puts_help("invalid sub action \"#{sub_action}\"")
      else
        puts_help("specify a sub action in #{sub_action_names}")
      end
    end

    def rpc(node, payload : String) : String
      res = HTTP::Client.post("#{node}/rpc", HTTP::Headers.new, payload)
      verify_response!(res)
    end

    def verify_response!(res) : String
      unless body = res.body
        puts_error "returned body is empty"
      end

      json = JSON.parse(body)

      if json["status"].as_s == "error"
        puts_error json["reason"].as_s
      end

      unless res.status_code == 200
        puts_error "failed to call an API. (#{res.body})"
      end

      json["result"].to_json
    end

    def add_transaction(node : String,
                        action : String,
                        wallets : Array(Core::Wallet),
                        senders : SendersDecimal,
                        recipients : RecipientsDecimal,
                        assets : Array(Asset),
                        modules : Array(Module),
                        inputs : Array(Input),
                        outputs : Array(Output),
                        linked : String,
                        message : String,
                        token : String,
                        kind : TransactionKind)
      raise "mismatch for wallet size and sender's size" if wallets.size != senders.size

      unsigned_transaction =
        create_unsigned_transaction(node, action, senders, recipients, assets, modules, inputs, outputs, linked, message, token, kind)

      signed_transaction = sign(wallets, unsigned_transaction)

      payload = {
        call:        "create_transaction",
        transaction: signed_transaction,
      }.to_json

      rpc(node, payload)

      if G.op.__json
        puts signed_transaction.to_json
      else
        puts_success "successfully create your transaction!"
        puts_success "=> #{signed_transaction.id}"
      end
    end

    def create_unsigned_transaction(node : String,
                                    action : String,
                                    senders : SendersDecimal,
                                    recipients : RecipientsDecimal,
                                    assets : Array(Asset),
                                    modules : Array(Module),
                                    inputs : Array(Input),
                                    outputs : Array(Output),
                                    linked : String,
                                    message : String,
                                    token : String,
                                    kind : TransactionKind) : Core::Transaction
      payload = {
        call:       "create_unsigned_transaction",
        action:     action,
        senders:    senders,
        recipients: recipients,
        assets:     assets,
        modules:    modules,
        inputs:     inputs,
        outputs:    outputs,
        linked:     linked,
        message:    message,
        token:      token,
        kind:       kind,
        version:    TransactionVersion::V1,
      }.to_json

      body = rpc(node, payload)

      Core::Transaction.from_json(body)
    end

    def sign(wallets : Array(Core::Wallet), transaction : Core::Transaction) : Core::Transaction
      transaction.as_signed(wallets)
    end

    def resolve_internal(node, domain) : JSON::Any
      payload = {call: "hra_resolve", domain_name: domain}.to_json

      body = rpc(node, payload)
      JSON.parse(body)
    end

    def lookup_internal(node, address) : JSON::Any
      payload = {call: "hra_lookup", address: address}.to_json

      body = rpc(node, payload)
      JSON.parse(body)
    end

    private def determine_address(node, wallet_path, wallet_password, address, domain) : String
      if _wallet_path = wallet_path
        wallet = get_wallet(_wallet_path, wallet_password)
        wallet.address
      elsif _address = address
        _address
      elsif _domain = domain
        resolved = resolve_internal(node, _domain)
        raise "domain #{_domain} is not resolved" unless resolved["resolved"].as_bool
        resolved["domain"]["address"].as_s
      else
        puts_help(HELP_WALLET_PATH_OR_ADDRESS_OR_DOMAIN)
      end
    end

    abstract def sub_actions : Array(AxeAction)
    abstract def option_parser : OptionParser?
    abstract def run_impl(action_name : String?) : OptionParser?

    include Helps
    include Logger
    include Core::TransactionModels
    include Common::Denomination
  end
end