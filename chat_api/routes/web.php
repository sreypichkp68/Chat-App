<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});

Route::get('/check-getenv', function () {
    return response()->json([
        'laravel_env' => env('CLOUDINARY_URL'),
        'native_getenv' => getenv('CLOUDINARY_URL'),
        'laravel_env_bytes' => bin2hex(env('CLOUDINARY_URL') ?? ''),
        'native_getenv_bytes' => bin2hex(getenv('CLOUDINARY_URL') ?: ''),
    ]);
});