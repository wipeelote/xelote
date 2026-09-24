--!strict
-- Per-player token bucket for remote traffic.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, stamp: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { rate: number, buckets: { [Player]: Bucket } },
	RateLimiter
))

function RateLimiter.new(perSecond: number): RateLimiter
	return setmetatable({ rate = perSecond, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.rate, stamp = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.rate, bucket.tokens + (now - bucket.stamp) * self.rate)
	bucket.stamp = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, player: Player)
	self.buckets[player] = nil
end

return RateLimiter
