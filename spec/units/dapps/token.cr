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

require "./../../spec_helper"

include Axentro::Core
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe Token do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.transaction_actions.should eq(["create_token", "update_token", "lock_token", "burn_token"])
    end
  end
  describe "#transaction_related?" do
    it "should return true when action is related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("create_token").should be_true
      end
    end
    it "should return false when action is not related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("unrelated").should be_false
      end
    end
  end

  describe "#valid_transaction?" do
    it "should pass when valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.passed.size.should eq(1)
        result.failed.size.should eq(0)
        result.passed.should eq([transaction])
      end
    end

    it "should raise an error when no senders" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [] of Transaction::Recipient
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("number of specified recipients must be 1 for 'create_token'")
      end
    end

    it "should raise an error when trying to create a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("AXNT", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise an error when trying to update a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_update_token("AXNT", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise an error when trying to lock a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_lock_token("AXNT")
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise address mismatch when sender address is different to recipient address" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("address mismatch for 'create_token'. sender: #{transaction_factory.sender_wallet.address}, recipient: #{transaction_factory.recipient_wallet.address}")
      end
    end

    it "should raise amount mismatch when sender amount is different to recipient amount" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.sender_wallet, 20_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("amount mismatch for 'create_token'. sender: 10, recipient: 20")
      end
    end

    describe "invalid token name" do
      it "should raise an error if token name is totally invalid" do
        is_valid_token_name("Inv al $d")
      end

      it "should raise an error if token name is invalid with underscores" do
        is_valid_token_name("TO_KEN")
      end

      it "should reject a transaction if invalid token name" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_create_token("KIN_GS", 10_i64)
          blockchain = block_factory.blockchain
          block_factory.add_slow_blocks(10).add_slow_block([transaction])

          if reject = blockchain.rejects.find(transaction.id)
            reject.reason.should eq("You token 'KIN_GS' is not valid\n\n1. token name can only contain uppercase letters or numbers\n2. token name length must be between 1 and 20 characters")
          else
            fail "no rejects found"
          end
        end
      end
    end

    it "should raise an error if the token already exists in previous transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(1)
        result.failed.first.reason.should eq("the token KINGS is already created")
      end
    end

    it "should raise an error if the token already exists" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_slow_block([transaction1]).add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        token.record(chain)
        transactions = [transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("the token KINGS is already created")
      end
    end

    it "create token quanity should fail if quantity is not a positive number greater than 0" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 0_i64)
        transaction2 = transaction_factory.make_create_token("KINGS2", -1_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(2)
        result.passed.size.should eq(0)
        result.failed.map(&.reason).should eq(["invalid quantity: 0, must be a positive number greater than 0", "invalid quantity: -1, must be a positive number greater than 0"])
      end
    end

    describe "After a token is created only the token creator may create more quantity of this token" do
      it "update token quantity should pass when done by the token creator when create is same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(2)
          result.passed.should eq(transactions)
        end
      end

      it "update token quantity should pass when done by the token creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(1)
          result.passed.should eq(transactions)
        end
      end

      it "update token quantity should fail if quantity is not a positive number greater than 0" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          transaction2 = transaction_factory.make_update_token("KINGS", 0_i64)
          transaction3 = transaction_factory.make_update_token("KINGS", -1_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(2)
          result.passed.size.should eq(1)
          result.passed.first.should eq(transaction1)
          result.failed.map(&.reason).should eq(["invalid quantity: 0, must be a positive number greater than 0", "invalid quantity: -1, must be a positive number greater than 0"])
        end
      end

      it "update token quantity should fail when done by not the creator when create is in the same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(1)
          result.passed.first.should eq(transaction1)
          result.failed.map(&.reason).should eq(["only the token creator can perform update token on existing token: KINGS"])
        end
      end

      it "update token quantity should fail when done by not the creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["only the token creator can perform update token on existing token: KINGS"])
        end
      end

      it "update token quantity should fail if no token exists" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["the token KINGS does not exist, you must create it before attempting to perform update token"])
        end
      end
    end

    describe "The token creator may choose to lock the token meaning they cannot create any more of that token" do
      it "lock token should pass when done by the token creator when create is same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64