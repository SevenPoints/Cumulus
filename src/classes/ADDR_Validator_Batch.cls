/*
    Copyright (c) 2014, Salesforce.com Foundation
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.com Foundation
* @date 2014
* @description Batch class for address verification.
*
* Batch process looks for all populated addresses and then updates them if the setting is turned on to do that.
*
* If skipPreviouslyVerified is true, the batch skips over objects that already have any verification records.
*/
public with sharing class ADDR_Validator_Batch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    private String query;
    
    public ADDR_Validator_Batch(Boolean skipPreviouslyVerified) {
    	//turn smartystreets verification on, so the batch verification works even if the checkbox wasn't checked by the user
    	Addr_Verification_Settings__c avs = UTIL_CustomSettingsFacade.getAddressVerificationSettings();
        if(avs.Class__c == 'ADDR_SmartyStreets_Validator') {
    	   avs.Using_SmartyStreets__c = true;
           if(!Test.isRunningTest())
               upsert avs;
        }
        
        //query for all US addresses
        query = 'select id, name, MailingStreet__c, MailingStreet2__c, Formula_MailingStreetAddress__c, MailingCity__c, MailingState__c, MailingPostalCode__c, MailingCountry__c, API_Response__c ' + 
            ' from Address__c where ' +
            '(MailingCountry__c = null or MailingCountry__c in (\'US\', \'USA\', \'United States\', \'United States of America\')) ' +
            'and (MailingStreet__c != null or MailingPostalCode__c != null or (MailingCity__c != null and MailingState__c != null))';
         
        if (skipPreviouslyVerified)
            query += ' and Verified__c != true';
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Address__c> scope) {
        list<Address__c> addressesToVerify = new list<Address__c>();
        for (Address__c a : scope)
            if (isUS(a)) addressesToVerify.add(a); 
        
        //verify and update this batch of addresses
        if (!addressesToVerify.isEmpty())
            ADDR_Validator.verifyAddressRecords(addressesToVerify);
    }
    
    public void finish(Database.BatchableContext bc) { }
    
    //Also called from ADDR_SmartyStreets_Validator. Since it's an auxiliary method we could move it to a separate 
    //class, but we'll keep it here for now because it's the only auxiliary one we have for address validation.
    public static Boolean isUS(Address__c c) {
        return ((c.MailingStreet__c != null || c.MailingPostalCode__c != null || (c.MailingCity__c != null && c.MailingState__c != null))
            && (c.MailingCountry__c == null || c.MailingCountry__c == 'US' || c.MailingCountry__c == 'USA' || 
                        c.MailingCountry__c == 'United States' || c.MailingCountry__c == 'United States of America'));
    }
}