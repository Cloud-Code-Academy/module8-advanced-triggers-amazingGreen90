/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance
Avoid DML inside for loop - 1 instance
Bulkify Your Code - 1 instance
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            // Set default Type for new Opportunities
            Opportunity opp = Trigger.new[0];
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }        
        } else if (Trigger.isDelete){
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        } else if (Trigger.isUpdate){
            // Append Stage changes in Opportunity Description
            for (Opportunity opp : Trigger.new){
                Opportunity oldOpp = Trigger.oldMap.get(opp.id);
                if (opp.StageName != oldOpp.StageName){
                    opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }
            }
        }
    }
    if (Trigger.isAfter){
        if (Trigger.isInsert){
            List<Task> taskToUpdate = new List<Task>();
            // Create a new Task for newly inserted Opportunities
            for (Opportunity opp : Trigger.new){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                taskToUpdate.add(tsk);
            }
            insert taskToUpdate;
        }
        // Send email notifications when an Opportunity is deleted 
        else if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } 
        // Assign the primary contact to undeleted Opportunities
        else if (Trigger.isUndelete){
            assignPrimaryContact(Trigger.newMap);
        }
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Set<Id> oppOwnerIds = new Set<Id>();
        for(Opportunity o : opps){
            oppOwnerIds.add(o.OwnerId);
        }
        String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id IN :oppOwnerIds].Email};
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {        
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
            accountIds.add(opp.AccountId);
        }
        List<Contact> contacts = [SELECT Id, AccountId, Name, Title FROM Contact WHERE AccountId IN :accountIds AND Title = 'VP Sales'];
        Map <Id, Contact> accToContacts = new Map <Id, Contact>();
        for (Contact con : contacts){
            accToContacts.put(con.AccountId, con);
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for(Opportunity opp : oppNewMap.values()){
            Id oppAcctId = opp.AccountId;
            if (accToContacts.containsKey(oppAcctId) && opp.Primary_Contact__c == null){
                Contact primaryCon = accToContacts.get(oppAcctId);
                Opportunity newOpp = new Opportunity(Id = opp.Id);
                newOpp.Primary_Contact__c = primaryCon.Id;
                oppsToUpdate.add(newOpp);
            }
        }
        update oppsToUpdate;
    }
}