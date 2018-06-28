require './blockchain'
require 'json'
require 'securerandom'
require 'sinatra'
require 'sinatra/reloader'

blockchain = Blockchain.new
node_identifier = SecureRandom.uuid.gsub(/-/, '')

post '/transaction/new' do
  valid_keys = ['sender', 'recipient', 'amount']
  data = JSON.parse request.body.string

  # Validation
  if data.keys.sort != valid_keys.sort
    status 400
    return "Invalid input"
  end

  index = blockchain.new_transaction(data['sender'], data['recipient'], data['amount'])

  status 200
  response = {message: "Transaction will be added to Block #{index}"}
  return response.to_json
end

get '/mine' do
  # return blockchain.chain.to_json
  # We run the proof of work algorithm to get the next proof...
  last_block = blockchain.last_block
  last_proof = last_block[:proof]
  proof = blockchain.proof_of_work(last_proof)

  # We must receive a reward for finding the proof.
  # The sender is "0" to signify that this node has mined a new coin.
  blockchain.new_transaction(0, node_identifier, 1)

  # Forge the new Block by adding it to the chain
  previous_hash = blockchain.hash(last_block)

  block = blockchain.new_block(proof, previous_hash)

  response = {
    message: 'New Block Forged',
    index: block[:index],
    transactions: block[:transactions],
    proof: block[:proof],
    previous_hash: block[:previous_hash]
  }

  status 200
  return response.to_json
end

get '/chain' do
  response = {
    chain: blockchain.chain,
    length: blockchain.chain.size
  }

  status 200
  return response.to_json
end

post '/register_node' do
  data = JSON.parse request.body.string

  unless data.has_key?('node')
    status 400
    return 'Input error'
  end

  blockchain.register_node(data['node'])

  response = {
    message: 'New nodes have been added',
    total_nodes: blockchain.nodes.to_a
  }

  status 200
  return response.to_json
end

get '/nodes' do
  status 200
  return {nodes: blockchain.nodes.to_a}.to_json
end

get '/consensus' do
  replaced = blockchain.resolve_conflicts

  if replaced
    response = {
      message: 'Our chain was replaced',
      new_chain: blockchain.chain
    }
  else
    response = {
      message: 'Our chain is authoriative',
      chain: blockchain.chain
    }
  end

  status 200
  return response.to_json
end
