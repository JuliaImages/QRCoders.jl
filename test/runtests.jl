using QRCode
using Test

import QRCode: getmode, Numeric, Alphanumeric, Byte
import QRCode.Polynomial: antilogtable, logtable, generator, Poly, geterrorcorrection

@testset "Test set for encoding modes" begin
    @test getmode("2983712983") == Numeric()
    @test getmode("ABCDEFG1234 \$%*+-./:") == Alphanumeric()
    @test getmode("ABC,") == Byte()
    @test getmode("ABCabc") == Byte()
    @test getmode("αβ") == Byte()
end


@testset "Test set for polynomials and error encoding" begin
    for i in 0:254
        @test i == antilogtable[logtable[i]]
    end

    for i in 1:255
        @test i == logtable[antilogtable[i]]
    end

    p = Poly(rand(UInt8, 10))
    q = Poly(rand(UInt8, 20))
    @test Poly([1]) * p == p
    @test p * q == q * p
    @test p + q == q + p

    @test p + p == Poly(zeros(UInt8, 10))

    @test Poly([1, 1]) * Poly([2, 1]) == Poly([2, 3, 1])
    @test Poly([1, 1]) * Poly([2, 1]) * Poly([4, 1]) == Poly([8, 14, 7, 1])

    @test generator(2) == Poly([2, 3, 1])
    @test generator(3) == Poly([8, 14, 7, 1])

    g7 = [21, 102, 238, 149, 146, 229, 87, 0]
    @test generator(7) == Poly(map(n -> logtable[n], g7))

    g8 = [28, 196, 252, 215, 249, 208, 238, 175, 0]
    @test generator(8) == Poly(map(n -> logtable[n], g8))

    g9 = [36, 123, 11, 149, 235, 231, 137, 246, 95, 0]
    @test generator(9) == Poly(map(n -> logtable[n], g9))

    g12 = [66, 157, 87, 131, 143, 198, 113, 187, 121, 98, 43, 102, 0]
    @test generator(12) == Poly(map(n -> logtable[n], g12))

    msg = [17, 236, 17, 236, 17, 236, 64, 67, 77, 220, 114, 209, 120, 11, 91, 32]
    r = [23, 93, 226, 231, 215, 235, 119, 39, 35, 196]
    @test geterrorcorrection(Poly(msg), 10) == Poly(r)

    msg = [70,247,118,86,194,6,151,50,16,236,17,236,17,236,17,236]
    r = [235, 159, 5, 173, 24, 147, 59, 33, 106, 40, 255, 172, 82, 2, 131, 32, 178, 236]
    @test geterrorcorrection(Poly(reverse(msg)), 18) == Poly(reverse(r))


end
