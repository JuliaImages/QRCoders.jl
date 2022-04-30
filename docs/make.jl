using Documenter, QRCode

DocMeta.setdocmeta!(QRCode, :DocTestSetup, :(using QRCode); recursive=true)

makedocs(
    sitename="QRCode.jl"
    , modules = [QRCode]
    )

deploydocs(
    repo = "github.com/JuliaImages/QRCode.jl.git",
)
