using Documenter, QRCoders

DocMeta.setdocmeta!(QRCoders, :DocTestSetup, :(using QRCoders); recursive=true)

makedocs(
    sitename="QRCoders.jl"
    , modules = [QRCoders]
    )

deploydocs(
    repo = "github.com/JuliaImages/QRCoders.jl.git",
    devurl = "master",
    versions = ["v#.#", "stable" => "v^", "dev" =>  "master"],
    # push_preview = true,
)
