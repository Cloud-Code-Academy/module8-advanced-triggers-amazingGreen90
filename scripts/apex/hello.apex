Opportunity opp = new  Opportunity(
    Name = 'Handler Opp',
    StageName = 'Prospecting',
    CloseDate = System.today(),
    Amount = Integer.valueOf(Math.random() * 100000));
insert opp;