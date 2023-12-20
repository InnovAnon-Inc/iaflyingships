local quaternion = {}
iaflyingships.math = {}
iaflyingships.math.quaternion = quaternion
local MODNAME = minetest.get_current_modname()

quaternion.__index = function(self, key)
    if type(key) == "number" then
        local idxmap = {"x", "y", "z", "w"}
        return rawget(self, idxmap[key] or key)
    else
        return rawget(quaternion, key) or rawget(self, key)
    end
end

quaternion.__newindex = function(self, key, value)
    if type(key) == "number" then
        local idxmap = {"x", "y", "z", "w"}
        rawset(self, idxmap[key] or key, value)
    else
        rawset(self, key, value)
    end
end

quaternion.new = function(x, y, z, w)
    if type(x) == "table" then
        return quaternion.new(x.x, x.y, x.z, x.w)
    end
    return setmetatable({x = x or 0, y = y or 0, z = z or 0, w = w or 0}, quaternion)
end

local binop = function(a, b, op)
    return {x = op(a.x, b.x), y = op(a.y, b.y), z = op(a.z, b.z), w = op(a.w, b.w)}
end

local add = function(a, b) return a + b end
local sub = function(a, b) return a - b end

quaternion.__add = function(self, other)
    return setmetatable(binop(self, other, add), quaternion)
end

quaternion.__sub = function(self, other)
    return setmetatable(binop(self, other, sub), quaternion)
end

quaternion.__unm = function(self)
    return quaternion.new(-self.x, -self.y, -self.z, -self.w)
end

quaternion.scalar = function(self)
    return self.w
end

quaternion.vector = function(self)
    return vector.new(self.x, self.y, self.z)
end

quaternion.__mul = function(self, other)
    if type(other) ~= "table" then
        return quaternion.new(self.x * other, self.y * other, self.z * other, self.w * other)
    end
    local selfvector = self:vector()
    local othervector = other:vector()
    local selfscalar = self:scalar()
    local otherscalar = other:scalar()
    local result = vector.add(vector.add(
        vector.multiply(othervector, selfscalar),
        vector.multiply(selfvector, otherscalar)),
        vector.cross(selfvector, othervector)
    )
    result.w = selfscalar * otherscalar - vector.dot(selfvector, othervector)
    return setmetatable(result, quaternion)
end

quaternion.conjugate = function(self)
    return quaternion.new(-self.x, -self.y, -self.z, self.w)
end

quaternion.rotate_no_scale = function(self, pos)
    local selfscalar = self:scalar()
    local selfvector = self:vector()
    local w2 = selfscalar * selfscalar
    local len2 = vector.dot(selfvector, selfvector)
    local result = vector.add(vector.add(
        vector.multiply(selfvector, 2 * vector.dot(selfvector, pos)),
        vector.multiply(vector.cross(selfvector, pos), 2 * selfscalar)
    ), vector.subtract(
        vector.multiply(pos, w2),
        vector.multiply(pos, len2)
    ))
    return vector.divide(result, len2 + w2)
end

quaternion.dot = function(self, other)
    local mul = binop(self, other, function(a, b) return a * b end)
    return mul.x + mul.y + mul.z + mul.w
end

quaternion.restricted_quaternion_multiply = function(q1, q2)
    local result = q1 * q2
    if (quaternion.dot(result, result)) >= 4 then
        result = result * .5
    end
    return result
end
