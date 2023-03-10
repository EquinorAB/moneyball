
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

module ::Axentro::Interface::Axe
  class Hra < CLI
    def sub_actions : Array(AxeAction)
      [
        {
          name: I18n.translate("axe.cli.hra.buy.title"),
          desc: I18n.translate("axe.cli.hra.buy.desc"),
        },
        {
          name: I18n.translate("axe.cli.hra.sell.title"),
          desc: I18n.translate("axe.cli.hra.sell.desc"),
        },
        {
          name: I18n.translate("axe.cli.hra.cancel.title"),
          desc: I18n.translate("axe.cli.hra.cancel.desc"),
        },
        {
          name: I18n.translate("axe.cli.hra.resolve.title"),
          desc: I18n.translate("axe.cli.hra.resolve.desc"),
        },
        {
          name: I18n.translate("axe.cli.hra.sales.title"),
          desc: I18n.translate("axe.cli.hra.sales.desc"),
        },
        {
          name: I18n.translate("axe.cli.hra.lookup.title"),
          desc: I18n.translate("axe.cli.hra.lookup.desc"),
        },
      ]
    end

    def option_parser : OptionParser?
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::JSON,
        Options::FEE,
        Options::PRICE,
        Options::DOMAIN,
        Options::CONFIG_NAME,
        Options::ADDRESS,
        Options::IS_FAST_TRANSACTION,
      ])
    end

    def run_impl(action_name) : OptionParser?
      case action_name
      when I18n.translate("axe.cli.hra.buy.title")
        return buy
      when I18n.translate("axe.cli.hra.cancel.title")
        return cancel
      when I18n.translate("axe.cli.hra.sell.title")
        return sell
      when I18n.translate("axe.cli.hra.resolve.title")
        return resolve
      when I18n.translate("axe.cli.hra.sales.title")
        return sales
      when I18n.translate("axe.cli.hra.lookup.title")
        return lookup
      end

      specify_sub_action!
    rescue e : Exception
      puts_error e.message
    end

    def buy
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_PRICE) unless price = G.op.__price
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      Core::DApps::BuildIn::Hra.valid_domain?(domain)

      resolved = resolve_internal(node, domain)

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, price, fee, "0")
      )

      recipients = RecipientsDecimal.new

      if resolved["resolved"].as_bool
        resolved_price = resolved["domain"]["price"].as_s
        resolved_address = resolved["domain"]["address"].as_s

        recipients.push(
          RecipientDecimal.new(resolved_address, resolved_price))
      end

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, "hra_buy", [wallet], senders, recipients, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", domain, TOKEN_DEFAULT, kind)
    end

    def sell
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_PRICE) unless price = G.op.__price
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain)

      raise "the domain #{domain} is not resolved" unless resolved["resolved"].as_bool

      if resolved["domain"]["status"] == Core::DApps::BuildIn::Status::FOR_SALE
        raise "the domain #{domain} is already for sale"
      end

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, price, fee, "0"))

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(wallet.address, price))

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, "hra_sell", [wallet], senders, recipients, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", domain, TOKEN_DEFAULT, kind)
    end

    def cancel
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_WALLET_PATH) unless wallet_path = G.op.__wallet_path
      puts_help(HELP_FEE) unless fee = G.op.__fee
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain)

      raise "the domain #{domain} is not resolved" unless resolved["resolved"].as_bool

      unless resolved["domain"]["status"] == Core::DApps::BuildIn::Status::FOR_SALE
        raise "the domain #{domain} is not for sale"
      end

      wallet = get_wallet(wallet_path, G.op.__wallet_password)

      senders = SendersDecimal.new
      senders.push(
        SenderDecimal.new(wallet.address, wallet.public_key, "0", fee, "0"))

      recipients = RecipientsDecimal.new
      recipients.push(
        RecipientDecimal.new(wallet.address, "0"))

      kind = G.op.__is_fast_transaction ? TransactionKind::FAST : TransactionKind::SLOW

      add_transaction(node, "hra_cancel", [wallet], senders, recipients, [] of Transaction::Asset, [] of Transaction::Module, [] of Transaction::Input, [] of Transaction::Output, "", domain, TOKEN_DEFAULT, kind)
    end

    def sales
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node

      payload = {call: "hra_for_sale"}.to_json

      body = rpc(node, payload)

      if G.op.__json
        puts body
      else
        puts_success "\n Human Readable Addresses for sale!\n"

        puts "   %20s | %64s | %s" % ["Domain", "Address", "Price"]

        json = JSON.parse(body)
        json.as_a.each do |domain|
          puts " - %20s | %64s | %s" % [domain["domain_name"].as_s, domain["address"].as_s, domain["price"].as_s]
        end

        puts
      end
    end

    def resolve
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_DOMAIN) unless domain = G.op.__domain

      resolved = resolve_internal(node, domain)

      if G.op.__json
        puts resolved.to_json
      else
        puts_success "show information of domain #{domain}"
        puts_success "resolved : #{resolved["resolved"]}"

        status = case resolved["domain"]["status"].as_i
                 when Core::DApps::BuildIn::Status::ACQUIRED
                   "acquired"
                 when Core::DApps::BuildIn::Status::FOR_SALE
                   "for sale"
                 when Core::DApps::BuildIn::Status::NOT_FOUND
                   "not found"
                 end

        puts_success "address  : #{resolved["domain"]["address"]}"
        puts_success "status   : #{status}"
        puts_success "price    : #{resolved["domain"]["price"].as_s}"
      end
    end

    def lookup
      puts_help(HELP_CONNECTING_NODE) unless node = G.op.__connect_node
      puts_help(HELP_LOOKUP_ADDRESS) unless address = G.op.__address

      json = lookup_internal(node, address)

      puts_success "\n Human Readable Address domains mapped to address #{address}\n"

      puts "   %s" % ["Domain"]

      json["domains"].as_a.each do |domain|
        puts " - %s" % [domain["domain_name"].as_s]
      end

      puts
    end
  end
end