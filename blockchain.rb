require 'date'
require 'time'
require 'json'
require 'digest'
require 'set'
require 'uri'
require 'net/http'

class Blockchain
  MINING_DIFFICULTY = '0000'
  attr_reader :chain, :current_transactions, :nodes

  def initialize
    @chain = []
    @current_transactions = []
    @nodes = Set.new

    # Create the genesis block
    new_block(1, 100)
  end

  # @param proof: [Integer] The proof given by the Proof of Work algorithm
  # @param previous_hash: [Integer] Hash of previous Block
  def new_block(proof, previous_hash=nil)
    block = {
      index: @chain.size + 1,
      timestamp: Time.parse(DateTime.now.to_s).to_i, # Unix Time
      transactions: @current_transactions,
      proof: proof,
      previous_hash: previous_hash ? previous_hash : hash(@chain[-1])
    }

    # Reset the current list of transactions
    @current_transactions = []

    @chain << block

    return block
  end

  # @param sender: [String] Address of the sender
  # @param recipient: [String] Address of the Recipient
  # @param amount: [Integer] Amount
  # return: [Integer] The index of the Block that will hold this transaction
  def new_transaction(sender, recipient, amount)
    @current_transactions << {
      sender: sender,
      recipient: recipient,
      amount: amount
    }

    return last_block[:index] + 1
  end

  def last_block
    @chain[-1]
  end

  # Create a SHA-256 hash of a Block
  # @param block: [Hash]
  # return: [String] SHA256 string
  def hash(block)
    block_string = JSON.generate block
    Digest::SHA256.hexdigest block_string
  end

  # Simple Proof of Work Algorithm:
  #   - Find a number p' such that hash(pp') contains leading 4 zeroes, where p is the previous p'
  #   - p is the previous proof, and p' is the new proof
  # @param last_proof: [Integer]
  def proof_of_work(last_proof)
    proof = 0

    while valid_proof(last_proof, proof) == false
      proof += 1
    end

    return proof
  end

  # Add a new node to the list of nodes
  # @param address: [String] Address of noe Eg. 'http://192.168.0.5:5000
  def register_node(address)
    parsed_url = URI(address)
    @nodes.add({host: parsed_url.host, port: parsed_url.port})
  end

  # This is our Consensus Algorithm, it resolves conflicts
  # by replacing our chain with the longest one in the network.
  # return: [Boolean] True if our chain was replaced, False if not
  def resolve_conflicts
    neighbours = @nodes
    new_chain = nil

    # We're only looking for chains longer than ours
    mmy_chain_length = @chain.length

    neighbours.each do |node|
      # Fetch others chain
      res = Net::HTTP.start(node[:host], node[:port]) do |http|
        http.get '/chain'
      end

      data = JSON.parse res.body
      length = data['length']
      chain = data['chain']

      # Check if the length is longer and the chain is valid
      if length > my_chain_length && valid_chain(chain)
        my_chain_length = length
        new_chain = chain
      end
    end

    if !!new_chain
      @chain = new_chain
      return true
    end
  end

  private

  # Validates the Proof: Does hash(last_proof, proof) contain 4 leading zeroes?
  # @param last_proof: [Integer] Previous Proof
  # @param proof: [Integer] Current Proof
  # return: [Boolean] True if correct
  def valid_proof(last_proof, proof)
    guess = "#{last_proof}#{proof}"
    guess_hash = Digest::SHA256.hexdigest guess

    return guess_hash[-MINING_DIFFICULTY.size..-1] == MINING_DIFFICULTY
  end

  # Determine if a given blockchain is valid
  # @param chain: [Array] A blockchain
  # return: [Boolean]
  def valid_chain(chain)
    last_block = chain[0]
    current_index = 1

    while current_index < chain.size
      block = chain[current_index]
      p last_block
      p block
      p '\n-------------\n'

      # Check that the hash of the block is correct
      if block[:previous_hash] != hash(last_block)
        return false
      end

      # Check that the Proof of Work is correct
      unless valid_proof(last_block[:proof], block[:proof])
        return false
      end

      last_block = block
      current_index += 1
    end

    return true
  end
end
