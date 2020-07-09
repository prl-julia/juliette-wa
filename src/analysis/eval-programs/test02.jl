
# Represents the size of an item
@enum Size BIG MEDIUM SMALL

# Represents an item in nature
abstract type Nature end

# Represents an animal in nature
struct Animal <: Nature
    species :: String
    size :: Size
    first_name :: String
end

# Represents a plant in nature
struct Plant <: Nature
    species :: String
    size :: Size
    color :: String
end

# Represents a bug in nature
struct Insect <: Nature
    species :: String
    size :: Size
end

# Represents a forest in nature
struct Forest <: Nature
    name :: String
    location :: Tuple{Int64, Int64}
    components :: Vector{Nature}
end

# Counts the number of bugs in the nature
bugCounter(nature :: Nature) :: Int64 = 0
bugCounter(bug :: Insect) :: Int64 = 1
function bugCounter(forest :: Forest) :: Int64
    countBugs = (nature, bugCount) -> bugCounter(nature) + bugCount
    foldr(countBugs, forest.components; init=0)
end

# Updates the bugcounter to not count the bugs (ie exterminate them!)
function exterminator(nature :: Nature) :: Nothing
    bugCount = bugCounter(nature)
    println("""There may be $(bugCount) bugs right now, but I am coming for you, bugs!""")
    eval(:(bugCounter(bug :: Insect) :: Int64 = 0))
    bugCount = bugCounter(nature)
    println("""Now I just need to wait until the next world age, and all $(bugCount) of you will be gone... **evil-laugh**""")
end

aspen = Plant("aspen", BIG, "tan")
lily = Plant("lily", SMALL, "purple")
bush = Plant("bush", MEDIUM, "green")
spider = Insect("tarantula", BIG)
beatle = Insect("dung beatle", MEDIUM)
ant = Insect("fire ant", SMALL)
moose = Animal("moose", BIG, "marty")
bear = Animal("black bear", MEDIUM, "bob")
deer = Animal("white tailed deer", MEDIUM, "dan")
components = [aspen, spider, spider, lily, ant,
                moose, bush, beatle, bear,deer]
forest = Forest("white river forest", (142, 443), components)

# Hire the exterminator...
exterminator(forest)
println("Bug count after the exterminator did his job: $(bugCounter(forest))")
