# Result Examples
# '000' => 0.016464000000269152s
# '0000' => 0.03351400000065041
# '00000' => 1.1384450000005018
# '000000' => 7.455480000000534
# '0000000' => 1201.4735369999999秒

require 'digest'
require 'benchmark'

result = Benchmark.realtime do
  proof = 0
  last_proof = 10
  guess_hash = []

  while guess_hash[-7..-1] != '0000000'
    guess = (proof * last_proof).to_s
    guess_hash = Digest::SHA256.hexdigest guess
    proof += 1
  end

  p 'Answer==' + proof.to_s
end

puts "処理時間: #{result}秒"
