@agent Wolf GridAgent{2} begin
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

@agent Sheep GridAgent{2} begin
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

function predator_prey(
    rng,
    n_sheep,
    n_wolves,
    dims,
    regrowth_time,
    sheep_reproduce,
    wolf_reproduce;
    Δenergy_sheep = 5,
    Δenergy_wolf = 13,
)
    space = GridSpace(dims, periodic = false)
    properties = (
        fully_grown = falses(dims),
        countdown = zeros(Int, dims),
        regrowth_time = regrowth_time,
    )
    model = ABM(
        Union{Wolf, Sheep},
        space,
        scheduler = Schedulers.ByType(true, true, Union{Wolf, Sheep}),
        properties = properties,
        rng = rng,
        warn=false
    )
    id = 0
    for _ in 1:n_sheep
        id += 1
        energy = rand(abmrng(model), 0:(Δenergy_sheep*2-1))
        sheep = Sheep(id, (0, 0), energy, sheep_reproduce, Δenergy_sheep)
        add_agent!(sheep, model)
    end
    for _ in 1:n_wolves
        id += 1
        energy = rand(abmrng(model), 0:(Δenergy_wolf*2-1))
        wolf = Wolf(id, (0, 0), energy, wolf_reproduce, Δenergy_wolf)
        add_agent!(wolf, model)
    end
    @inbounds for p in positions(model)
        fully_grown = rand(abmrng(model), Bool)
        countdown = fully_grown ? regrowth_time : rand(abmrng(model), 0:regrowth_time-1)
        model.countdown[p...] = countdown
        model.fully_grown[p...] = fully_grown
    end
    return model, agent_step!, model_step!
end

function agent_step!(agent, model)
    randomwalk!(agent, model, 1)
    agent.energy -= 1
    eat!(agent, model)
    if agent.energy < 0
        remove_agent!(agent, model)
    elseif rand(abmrng(model)) <= agent.reproduction_prob
        reproduce!(agent, model)
    end
end

function eat!(sheep::Sheep, model)
    if model.fully_grown[sheep.pos...]
        sheep.energy += sheep.Δenergy
        model.fully_grown[sheep.pos...] = false
    end
end

function eat!(wolf::Wolf, model)
    agents = agents_in_position(wolf.pos, model)
    sheeps = Iterators.filter(x -> typeof(x) == Sheep, agents)
    if !isempty(sheeps)
        dinner = rand(abmrng(model), collect(sheeps))
        remove_agent!(dinner, model)
        wolf.energy += wolf.Δenergy
    end
end

function reproduce!(agent, model)
    agent.energy /= 2
    offspring = typeof(agent)(
        nextid(model),
        agent.pos,
        agent.energy,
        agent.reproduction_prob,
        agent.Δenergy,
    )
    add_agent_pos!(offspring, model)
end

function model_step!(model)
    @inbounds for p in positions(model)
        if !(model.fully_grown[p...])
            if model.countdown[p...] ≤ 0
                model.fully_grown[p...] = true
                model.countdown[p...] = model.regrowth_time
            else
                model.countdown[p...] -= 1
            end
        end
    end
end