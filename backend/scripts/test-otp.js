'use strict';

/**
 * Utility script to test the Owner OTP flow.
 * Run this from the backend folder using: node scripts/test-otp.js
 *
 * Flow:
 * 1. Request OTP for a test email.
 * 2. User retrieves the code from the backend console (Nodemon terminal).
 * 3. Verify the OTP.
 */
const axios = require('axios');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const BASE_URL = 'http://localhost:5000/api/auth';
const testEmail = 'test-owner@example.com';

async function testOtpFlow() {
  console.log(`\n--- STEP 1: Requesting OTP for: ${testEmail} ---`);

  try {
    const requestRes = await axios.post(`${BASE_URL}/owner/request-otp`, {
      email: testEmail
    });

    console.log('Request Status:', requestRes.status);
    console.log('Request Data:', requestRes.data);
    console.log('\n[ACTION] Check your backend terminal (the one running npm run dev) for the 6-digit code.');

    rl.question('\nEnter the 6-digit code here to verify: ', async (otpCode) => {
      console.log(`\n--- STEP 2: Verifying OTP: ${otpCode} ---`);

      try {
        const verifyRes = await axios.post(`${BASE_URL}/owner/verify-otp`, {
          email: testEmail,
          otpCode: otpCode.trim()
        });

        console.log('Verify Status:', verifyRes.status);
        console.log('Verify Data:', verifyRes.data);
        console.log('\n✅ SUCCESS: Owner OTP flow verified end-to-end.');
      } catch (error) {
        console.error('\n❌ VERIFICATION ERROR:');
        if (error.response) {
          console.error(JSON.stringify(error.response.data, null, 2));
        } else {
          console.error(error.message);
        }
      } finally {
        rl.close();
      }
    });

  } catch (error) {
    console.error('\n❌ REQUEST ERROR:');
    if (error.response) {
      console.error(JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
    rl.close();
  }
}

testOtpFlow();
