using Documenter, QRCoders

DocMeta.setdocmeta!(QRCoders, :DocTestSetup, :(using QRCoders); recursive=true)

makedocs(
    sitename="QRCoders.jl"
    , modules = [QRCoders]
    )

deploydocs(
    repo = "github.com/JuliaImages/QRCoders.jl.git",
    devurl = "dev",
    devbranch = "master",
    versions = ["v#.#", "stable" => "v^", "dev" =>  "dev"],
)
